classdef PoissonStimulusTrain_discrete2_newer < handle
  
  %------- Constants
  properties (Constant)
    CHOICES           = Choice.all()    % All available choices
    
    MAX_RETRIES       = 100             % Maximum number of attempts to find a nearby index
  end
  
  %------- Private data
  properties (Access = protected, Transient)
    default           % Defaults for various data formats
  end

  %------- Public data
  properties (SetAccess = protected)
    cfgIndex          % Index of the currently configured stimulus type

    targetNumTrials   % Number of trials to pre-generate per session
    fracDuplicated    % Fraction of per-session trials that will have duplicates (includes the duplicates)
    trialDuplication  % Duplication factor for subset of per-session trials that have duplicates
    trialDispersion   % The amount of stagger (in units of number of trials) when mixing trial sequences
    panSessionTrials  % Number of trials to pre-generate for use across sessions
    numSessionSets    % Number of per-session trial sets to generate
    
    config            % Stimulus train configuration
    panSession        % Pan-session bank of stimulus trains
    perSession        % Per-session stimulus trains
  end
  
  properties (SetAccess = protected, Transient)
    setIndex          % Index of the currently configured stimulus set (per-session trials)
    trialIndex        % Index of the currently selected trial

    selTrials         % Indices to perSession (positive) / panSession (negative) entries, in the requested mixed sequence
    quasiRand         % Quasi-random number stream for mixing trials
  end
  
  
  %________________________________________________________________________
  methods

    %----- Structure version to store an object of this class to disk
    function frozen = saveobj(obj)

      % Use class metadata to determine what properties to save
      metadata      = metaclass(obj);
      
      % Store all mutable and non-transient data
      for iProp = 1:numel(metadata.PropertyList)
        property    = metadata.PropertyList(iProp);
        if ~property.Transient && ~property.Constant
          frozen.(property.Name)  = obj.(property.Name);
        end
      end
      
    end
    
    %----- Constructor
    function obj = PoissonStimulusTrain_discrete2_newer(targetNumTrials, fracDuplicated, trialDuplication, trialDispersion, panSessionTrials, numSessionSets)
      
      % Stimulus configuration data structure
      obj.default.cfg.lCue           = nan;
      obj.default.cfg.cueVisAt       = nan;
      obj.default.cfg.maxNumCues     = nan;
      obj.default.cfg.minCueSep      = nan;
      obj.default.cfg.densityPerM    = nan;
      obj.default.cfg.meanRatio      = nan;
      obj.default.cfg.meanSalient    = nan;
      obj.default.cfg.meanDistract   = nan;
      obj.default.cfg.FracEdgeTrials = nan;
      obj.default.cfg.EdgeProbDef    = nan;
        
      % Stimulus train data structure
      obj.default.stim.cuePos       = cell(size(PoissonStimulusTrain_discrete2_newer.CHOICES));
      obj.default.stim.cueCombo     = nan(numel(PoissonStimulusTrain_discrete2_newer.CHOICES), 0);
      obj.default.stim.nSalient     = nan;
      obj.default.stim.nDistract    = nan;
      obj.default.stim.index        = nan;
      
      % Stimulus trains
      obj.cfgIndex                  = [];
      obj.setIndex                  = 1;
      obj.trialIndex                = [];
      obj.numSessionSets            = 1;
      obj.config                    = repmat(obj.default.cfg  , 0);
      obj.panSession                = repmat(obj.default.stim, 0);
      obj.perSession                = repmat(obj.default.stim, 0);
      if nargin > 0
        obj.setTrialMixing(targetNumTrials, fracDuplicated, trialDuplication, trialDispersion, panSessionTrials, numSessionSets);
      end
      
      obj.quasiRand                 = qrandstream(scramble(haltonset(1, 'Skip', 1e3, 'Leap', 1e2), 'RR2'));
      
    end

     %----- Copy info from struct
    function copyStruct(obj, source)
      
      % Merge all fields from the frozen copy into the new object
      for field = fieldnames(source)'
        if strcmp(field{:}, 'config')
          default       = obj.default.cfg;
        elseif ~isempty(regexp(field{:}, '^p.+Session$', 'once'))
          default       = obj.default.stim;
        else
          default       = struct();
        end
        
        obj.(field{:})  = mergestruct ( obj.(field{:})      ...
                                      , source.(field{:})   ...
                                      , default             ...
                                      );
        if numel(obj.(field{:})) > 1
          obj.(field{:})= reshape(obj.(field{:}), size(source.(field{:})));
        end
      end

      % Initialize indexing into trial banks
      obj.trialIndex    = zeros(size(obj.config));
      
    end

   %----- Sets the number and mixture of trials drawn by configure()
    function setTrialMixing(obj, targetNumTrials, fracDuplicated, trialDuplication, trialDispersion, panSessionTrials, numSessionSets)
      
%       if ~isempty(obj.perSession)
%         error('setTrialMixing:precondition', 'This can only be called prior to generation of any trials via configure().');
%       end
      
      obj.targetNumTrials           = targetNumTrials;
      obj.fracDuplicated            = fracDuplicated;
      obj.trialDuplication          = trialDuplication;
      obj.trialDispersion           = trialDispersion;      
      obj.panSessionTrials          = panSessionTrials;
      obj.numSessionSets            = numSessionSets;

      obj.panSession                = repmat(obj.default.stim, 0);
      obj.perSession                = repmat(obj.default.stim, 0);
      
    end
      
    %----- Sets which per-session stimulus set to use for trials 
    function setStimulusIndex(obj, stimulusSet)
      obj.setIndex  = stimulusSet;
    end
    
    %----- Pre-generate (if necessary) stimulus trains for a given configuration
    function [modified, stimulusIndex] = configure(obj, lCue, cueVisAt, cueDensityPerM, cueMeanRatio, maxNumCues, cueMinSeparation, FracEdgeTrials, EdgeProbDef)
      
      if isempty(obj.targetNumTrials)
        error('configure:precondition', 'This can only be called after the number of trials to generate is set via the constructor or setTrialMixing().');
      end
      
      % Return value is true if non-transient changes have been made
      modified                      = false;
      
      % Try to locate an existing configuration of the desired type
      obj.cfgIndex                  = 1;
      while obj.cfgIndex <= numel(obj.config)
        if      obj.config(obj.cfgIndex).lCue         == lCue               ...
            &&  obj.config(obj.cfgIndex).cueVisAt     == cueVisAt           ...
            &&  obj.config(obj.cfgIndex).maxNumCues   == maxNumCues         ...
            &&  obj.config(obj.cfgIndex).minCueSep    == cueMinSeparation   ...
            &&  obj.config(obj.cfgIndex).densityPerM  == cueDensityPerM     ...
            &&  obj.config(obj.cfgIndex).meanRatio    == cueMeanRatio       ...
            &&  obj.config(obj.cfgIndex).FracEdgeTrials == FracEdgeTrials   ...
            &&  obj.config(obj.cfgIndex).EdgeProbDef == EdgeProbDef            
          break;
        end
        obj.cfgIndex                = obj.cfgIndex + 1;
      end
      
      % Generate a new configuration if necessary
      if obj.cfgIndex > numel(obj.config)
        modified                    = true;
        cueMeanCount                = cueDensityPerM * (lCue/100);
        cfg                         = obj.default.cfg;
        cfg.lCue                    = lCue;
        cfg.cueVisAt                = cueVisAt;
        cfg.maxNumCues              = maxNumCues;
        cfg.minCueSep               = cueMinSeparation;
        cfg.meanRatio               = cueMeanRatio;
        cfg.densityPerM             = cueDensityPerM;
        cfg.meanDistract            = cueMeanCount / (1 + exp(cueMeanRatio));
        cfg.meanSalient             = cueMeanCount - cfg.meanDistract;
        cfg.FracEdgeTrials          = FracEdgeTrials;
        cfg.EdgeProbDef             = EdgeProbDef;
        obj.config(obj.cfgIndex)    = cfg;
      else
        cfg                         = obj.config(obj.cfgIndex);
      end
      
      
      % Draw per-/pan-session trials for this configuration if necessary
      if      obj.cfgIndex > size(obj.perSession,1)                     ...
          ||  isempty(obj.perSession(obj.cfgIndex,1).index)             ...
          ||  isnan(obj.perSession(obj.cfgIndex,1).index)
        
        % Compute the number of unique per-session trials:
        %   noDuplicates + dupFactor * duplicated = target
        %                  dupFactor * duplicated = fracDuplicated * target
        %   unique  = noDuplicates + duplicated
        %           = (1 - fracDuplicated)*target + (fracDuplicated/dupFactor)*target
        nPerSessionTrials           = ceil( ( 1 - obj.fracDuplicated                        ...
                                                + obj.fracDuplicated/obj.trialDuplication   ...
                                            ) * obj.targetNumTrials                           ...
                                          );
        for iSet = obj.numSessionSets:-1:1
          for iTrial = nPerSessionTrials:-1:1
            obj.perSession(obj.cfgIndex, iTrial, iSet)  = obj.poissonTrains(cfg, iTrial);
          end
        end
        
        for iTrial = obj.panSessionTrials:-1:1
          obj.panSession(obj.cfgIndex, iTrial) = obj.poissonTrains(cfg, -iTrial);
        end
      end
      
      % Generate a mixture of trials for this session
      obj.selTrials                 = obj.mixTrials ( 1:size(obj.perSession, 2)   ...
                                                    , -1:-1:-obj.panSessionTrials   ...
                                                    );
      stimulusIndex                 = obj.cfgIndex;
      
    end

    %----- Obtain the currently set configuration
    function cfg = currentConfig(obj)
      
      cfg               = obj.config(obj.cfgIndex);
      
    end
    
    %----- Restart from first trial
    function restart(obj)
      obj.trialIndex(obj.cfgIndex)  = 0;
    end
    
    %----- Obtain stimulus train for the currently set configuration
    function trial = nextTrial(obj)
      
      % Increment trial index and handle special case of no more trials
      obj.trialIndex(obj.cfgIndex)  = obj.trialIndex(obj.cfgIndex) + 1;
      if obj.trialIndex(obj.cfgIndex) > numel(obj.selTrials)
        trial           = [];
        return;
      end
      
      % If there are trials remaining, return them
      index             = obj.selTrials(obj.trialIndex(obj.cfgIndex));
      if index < 0
        trial           = obj.panSession(obj.cfgIndex, -index);
      else
        trial           = obj.perSession(obj.cfgIndex, index, obj.setIndex);
      end
      
    end
    
  end
    
    
  %________________________________________________________________________
  methods (Access = protected)
    
    %----- Generate salient and distractor Poisson distributed stimulus trains
    function stim = poissonTrains(obj, cfg, index)

      % Canonical order of trains as salient first, distractor second
      stim                      = obj.default.stim;
      stim.index                = index;
      meanNumCues               = [cfg.meanSalient, cfg.meanDistract];
      maxNumCues                = floor((cfg.lCue-cfg.minCueSep)/cfg.minCueSep);
      
      if isfinite(cfg.cueVisAt)
        cueOffset               = cfg.cueVisAt;
      else
        cueOffset               = 0;
      end

      % Distribute cues on each side of the maze
      nCues                     = [];
      cuePos                    = [];
      cueSide                   = [];
      while isempty(cuePos)     % Mazes must have at least one cue


        isEdgeTrial = rand< cfg.FracEdgeTrials;
        if ~isEdgeTrial %normal case
            nCuesTotal = sum(nCues);
            while nCuesTotal > maxNumCues || nCuesTotal==0
                for iSide = 1:numel(meanNumCues)
                    % Draw a Poisson count of towers within available length
                    nCues(iSide)        = poissrnd(meanNumCues(iSide));
                end
                nCuesTotal = sum(nCues);
            end
        else %edge trial case
            x_skell = -50:50;
            skellam_pdf = exp(-sum(meanNumCues))*((meanNumCues(1)/meanNumCues(2)).^(x_skell/2)).*besseli(x_skell,2*sqrt(prod(meanNumCues)));
            skellam_cdf = sum(triu(gallery('circul',skellam_pdf)));
            x_skell_edge_ind = find(skellam_cdf >(1-cfg.EdgeProbDef),1,'first');

            possible_diff_cues_inds = x_skell_edge_ind:find(x_skell==maxNumCues);                    
            cur_probs = skellam_pdf(possible_diff_cues_inds)/sum(skellam_pdf(possible_diff_cues_inds));
            cur_cdf = sum(triu(gallery('circul',cur_probs)));
            diff_nCues_ind = possible_diff_cues_inds(find(cur_cdf>rand,1,'first'));
            diff_cCues = x_skell(diff_nCues_ind);
            possible_nCues1 = diff_cCues:maxNumCues;
            cond_pdf = poisspdf(possible_nCues1 ,meanNumCues(1)).*poisspdf(0:(maxNumCues-diff_cCues),meanNumCues(2));
            cond_pdf = cond_pdf/sum(cond_pdf); 
            cond_cdf = sum(triu(gallery('circul',cond_pdf)));
            nCues(1) = possible_nCues1(find(cond_cdf>rand,1,'first'));
            nCues(2) = nCues(1)-diff_cCues;

        end
        nCuesTotal=sum(nCues);
        
        lEffective = (cfg.lCue-cfg.minCueSep) - cueOffset - (nCuesTotal - 1) * cfg.minCueSep;
        stim_cuePos_all = cueOffset + sort(rand(1, nCuesTotal)) * lEffective    ...
            + (0:nCuesTotal - 1) * cfg.minCueSep;
        % shift by a random number (uniform across length of visible stimuli , which is cfg.lCue - cueOffset) with wraparound.
        % that way we avoid clutering at the edges of the cue distribution in space.
        rand_shift = rand*(cfg.lCue - cueOffset);
        stim_cuePos_all=stim_cuePos_all+rand_shift;
        stim_cuePos_all(stim_cuePos_all>cfg.lCue) = stim_cuePos_all(stim_cuePos_all>cfg.lCue)- (cfg.lCue - cueOffset);
        rand_cues_assign=randperm(nCuesTotal );
        already_assigned=0;
        for iSide = 1:numel(meanNumCues)
            cur_assign = rand_cues_assign(already_assigned+1:already_assigned+nCues(iSide));
            stim.cuePos{iSide}    = sort(stim_cuePos_all(cur_assign));
            already_assigned=already_assigned+nCues(iSide);
            cueRange              = numel(cuePos) + (1:numel(stim.cuePos{iSide}));
            cuePos(cueRange)      = stim.cuePos{iSide};
            cueSide(cueRange)     = iSide;
        end
      end

	  % Store canonical (bit pattern) representation of cue presence
      [~, index]                = sort(cuePos);
      cueSide                   = cueSide(index);
      stim.cueCombo             = false(numel(PoissonStimulusTrain_discrete2_newer.CHOICES), numel(cueSide));
      for iSide = 1:size(stim.cueCombo, 1)
        for iSlot = 1:numel(cueSide)
          stim.cueCombo(cueSide(iSlot), iSlot)  = true;
        end
      end

      % Make sure the correct side has more cues
      if nCues(2) > nCues(1)
        stim.cuePos             = flip(stim.cuePos);
        stim.cueCombo           = flipud(stim.cueCombo);
      end
      stim.nSalient             = nCues(1);
      stim.nDistract            = nCues(2);

    end
  
    %----- Generate a balanced mixture of trials 
    function mix = mixTrials(obj, perSession, panSession)
      
%       figure ; hold on;
      
      % Keep track of assigned slots
      mix             = nan(1, obj.targetNumTrials + numel(panSession));
      
      % Fill with pan-session trials
      mix             = obj.randomlyAssignTrials(mix, panSession, obj.trialDispersion);
%       plot(1:numel(mix),mix,'sr','markersize',3);

      % Select a subset of trials to duplicate
      numDuplicated   = ceil( obj.fracDuplicated * obj.targetNumTrials / obj.trialDuplication );
      dupSelect       = qrand(obj.quasiRand, numel(perSession)) * numel(perSession) < numDuplicated;
      dupSelect       = obj.adjustSelectCount(dupSelect, numDuplicated);
      dupTrials       = perSession(dupSelect);
      
      % In the case of a high replica number, adjust the dispersion factor so that the separation
      % between two adjacent slots remains about the same. TODO:  Do math better!
      dupDisperson    = sqrt(obj.trialDuplication) * obj.trialDispersion;

      % Fill with per-session duplicates
      duplications    = obj.trialDuplication - 1;
      while duplications >= 1
        mix           = obj.randomlyAssignTrials(mix, dupTrials, dupDisperson);
        duplications  = duplications - 1;
      end

      % If a fractional duplication factor was specified, only a subset of trials will be replicated
      if duplications > 0
        select        = qrand(obj.quasiRand, numel(dupTrials)) < duplications;
        select        = obj.adjustSelectCount(select, round(duplications * numel(dupTrials)));
        mix           = obj.randomlyAssignTrials(mix, dupTrials(select), dupDisperson);
      end
      
      %{
      plot(1:numel(mix),mix,'dg','markersize',3);
      unassigned      = isnan(mix);
      %}
      
      % Fill remaining slots with original sequence of trials
      iTrial          = 0;
      for iSlot = 1:numel(mix)
        if isnan(mix(iSlot))
          iTrial      = iTrial + 1;
          mix(iSlot)  = iTrial;
        end
      end
      
      %{
      plot(1:numel(mix),mix,'+k','markersize',3,'linewidth',1);
      idx = 1:numel(mix);
      h = bar(idx(unassigned), 1:iTrial, 'y', 'linestyle','none');
      uistack(h,'bottom');
      uu=unique(mix); tt=arrayfun(@(x) conditional(x<0,-1,sum(mix==x)), uu);
      [ sum(tt==-1), sum(tt==1), sum(tt>1) ]
      %}

%       % Sanity check
%       if iTrial > perSession(end)
%         error('mixTrials:sanity', 'Assigned invalid index %d > %d of trials.', iTrial, perSession(end));
%       end
      
    end
    
    %----- Helper for mixTrials() to randomly disperse indices
    function mix = randomlyAssignTrials(obj, mix, indices, trialDispersion)
      
      if isempty(indices)
        return;
      end
      
      % Initialize with central locations for the given indices
%       target      = obj.trialDispersion/2                       ...
%                   + ( numel(mix) - obj.trialDispersion )        ...
%                   * sort(qrand(obj.quasiRand, numel(indices)))  ...
%                   ;
      target      = 1 + numel(mix) * sort(qrand(obj.quasiRand, numel(indices)));
                
      % Disperse targets (rolled out pass for speed)
      shift       = randn(1, numel(indices)) * trialDispersion;
      
      % Prevent collisions of slot assignments
      for iIdx = 1:numel(indices)
        slot      = round( target(iIdx) + shift(iIdx) );
        iTry      = 1;
        while     slot < 1            ...
              ||  slot > numel(mix)   ...
              ||  ~isnan(mix(slot))
          slot    = round( target(iIdx) + randn() * obj.trialDispersion );
          iTry    = iTry + 1;
          
          % If maximum number of attempts has been exceeded, locate the nearest available slot
          if iTry > obj.MAX_RETRIES
            candidate   = find(isnan(mix));
            [~,iCand]   = min( abs(candidate - round(target(iIdx))) );
            slot        = candidate(iCand);
            break;
          end
        end
        mix(slot) = indices(iIdx);
      end
      
    end
    
  end
  
  
  %________________________________________________________________________
  methods (Static)

    %----- Load object from disk
    function obj = loadobj(frozen)

      % Start from default constructor
      obj               = PoissonStimulusTrain_discrete2_newer();
      obj.copyStruct(frozen);
            
    end
    
    %----- Helper for mixTrials() to randomly (un)select items
    function select = adjustSelectCount(select, numTarget)
      
      numSelected           = sum(select);
      if numSelected > numTarget
        targetValue         = true;
        increment           = -1;
      else
        targetValue         = false;
        increment           = 1;
      end
      
      while numSelected ~= numTarget
        indices             = randi([1, numel(select)]);
        for index = indices
          if select(index) == targetValue
            select(index)   = ~targetValue;
            numSelected     = numSelected + increment;
          end
        end
      end

    end
    
  end
  
end
