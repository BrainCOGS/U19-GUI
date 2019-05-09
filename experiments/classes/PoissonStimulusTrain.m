classdef PoissonStimulusTrain < handle
  
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
    function obj = PoissonStimulusTrain(targetNumTrials, fracDuplicated, trialDuplication, trialDispersion, panSessionTrials, numSessionSets)
      
      % Stimulus configuration data structure
      obj.default.cfg.lCue          = nan;
      obj.default.cfg.cueVisAt      = nan;
      obj.default.cfg.maxNumCues    = nan;
      obj.default.cfg.minCueSep     = nan;
      obj.default.cfg.densityPerM   = nan;
      obj.default.cfg.meanRatio     = nan;
      obj.default.cfg.meanSalient   = nan;
      obj.default.cfg.meanDistract  = nan;
      
      % Stimulus train data structure
      obj.default.stim.cuePos       = cell(size(PoissonStimulusTrain.CHOICES));
      obj.default.stim.cueCombo     = nan(numel(PoissonStimulusTrain.CHOICES), 0);
      obj.default.stim.nSalient     = nan;
      obj.default.stim.nDistract    = nan;
      obj.default.stim.index        = nan;
      
      % Stimulus trains
      obj.cfgIndex                  = [];
      obj.setIndex                  = 1;
      obj.trialIndex                = [];
      obj.numSessionSets            = 1;
      obj.config                    = repmat(obj.default.cfg , 0);
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
    function [modified, stimulusIndex] = configure(obj, lCue, cueVisAt, cueDensityPerM, cueMeanRatio, maxNumCues, cueMinSeparation)
      
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
            &&  obj.config(obj.cfgIndex).meanRatio    == cueMeanRatio
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
      obj.selTrials                 = obj.mixTrials ( 1:size(obj.perSession, 2)     ...
                                                    , -1:-1:-obj.panSessionTrials   ...
                                                    );
      stimulusIndex                 = obj.cfgIndex;
      
    end

    %----- Obtain the currently set configuration
    function cfg = currentConfig(obj)
      
      cfg = obj.config(obj.cfgIndex);
      
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
        for iSide = 1:numel(meanNumCues)
          % Draw a Poisson count of towers within available length
          nCues(iSide)          = poissrnd(meanNumCues(iSide));
          while nCues(iSide) > cfg.maxNumCues
            nCues(iSide)        = poissrnd(meanNumCues(iSide));
          end

          % Distribute cues uniformly in effective length
          lEffective            = cfg.lCue - cueOffset - (nCues(iSide) - 1) * cfg.minCueSep;
          stim.cuePos{iSide}    = cueOffset + sort(rand(1, nCues(iSide))) * lEffective    ...
              + (0:nCues(iSide) - 1) * cfg.minCueSep  ;
          % shift by a random number (uniform across length of visible stimuli , which is cfg.lCue - cueOffset) with wraparound.
          % that way we avoid clutering at the edges of the cue distribution in space.
          rand_shift = rand*(cfg.lCue - cueOffset);
          stim.cuePos{iSide}=stim.cuePos{iSide}+rand_shift;
          stim.cuePos{iSide}(stim.cuePos{iSide}>cfg.lCue) = stim.cuePos{iSide}(stim.cuePos{iSide}>cfg.lCue)- (cfg.lCue - cueOffset);
          cueRange              = numel(cuePos) + (1:numel(stim.cuePos{iSide}));
          cuePos(cueRange)      = stim.cuePos{iSide};
          cueSide(cueRange)     = iSide;
        end
        
        if all(meanNumCues == 0)
            break; 
        end
      end

      % Store canonical (bit pattern) representation of cue presence
      [~, index]                = sort(cuePos);
      cueSide                   = cueSide(index);
      stim.cueCombo             = false(numel(PoissonStimulusTrain.CHOICES), numel(cueSide));
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
      obj               = PoissonStimulusTrain();
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
