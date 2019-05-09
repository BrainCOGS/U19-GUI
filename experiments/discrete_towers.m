function code = discrete_towers
% poisson_towers   Code for the ViRMEn experiment poisson_towers.
%   code = poisson_towers   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT

code.setup  = @setupTrials;



%%_________________________________________________________________________
% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)

% Number and sequence of trials, reward level etc.
vr    = setupTrials(vr);

% Standard communications lines for VR rig
vr    = initializeVRRig(vr, vr.exper.userdata.trainee);

% Initialize standard state control variables
vr    = initializeGradedExperiment(vr);

if ~vr.experimentEnded
  % Load the first maze
  vr  = computeWorld(vr);
end



%****** DEBUG DISPLAY ******
if ~RigParameters.hasDAQ && ~RigParameters.simulationMode
  vr.text(1).position     = [-1 0.7];
  vr.text(1).size         = 0.03;
  vr.text(1).color        = [1 1 0];
  vr.text(2).position     = [-1 0.65];
  vr.text(2).size         = 0.03;
  vr.text(2).color        = [1 1 0];
  vr.text(3).position     = [-1.6 0.9];
  vr.text(3).size         = 0.02;
  vr.text(3).color        = [1 1 0];
  vr.text(4).position     = [-1.6 0.85];
  vr.text(4).size         = 0.02;
  vr.text(4).color        = [1 1 0];
end
%***************************


%%_________________________________________________________________________
% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)
try

  
    % TEST: use sounds for specific mice
    switch vr.exper.userdata.trainee.name
        case 'Abraham'
            UseSounds = 1;
        case 'Ernst'
            UseSounds = 1;
        case 'test20'
            UseSounds = 1;
        otherwise
            UseSounds = 0;
    end       
    %
    
% Handle communications at a reduced frequency
if ~isempty(vr.pager)
%   vr.runCount   = vr.runCount + 1;
%   if vr.runCount >= 10
%     vr.runCount = 0;
    vr.pager.heartbeat();
%   end
end

% Handle keyboard, remote input, wait times
vr  = processKeypress(vr, vr.protocol);
vr  = processRemoteControl(vr);
vr  = processWaitTimes(vr);
vr.prevState  = vr.state;


% Apply motion rules
if vr.collision && isfinite(vr.frictionCoeff)
  vr.dp = vr.dp * vr.frictionCoeff;
end

% Forced termination
if isinf(vr.protocol.endExperiment)
  vr.experimentEnded  = true;
elseif vr.waitTime == 0   % Only if not in a time-out period...
switch vr.state           % ... take action depending on the simulation state
  
  %========================================================================
  case BehavioralState.SetupTrial
    % Configure world for the trial; this is done separately from 
    % StartOfTrial as it can take a long time and we want to teleport the
    % animal back to the start location only after this has been completed
    % and the Virmen engine can do whatever behind-the-scenes magic. If we
    % try to merge this step with StartOfTrial, animal motion can
    % accumulate during initialization and result in an artifact where the
    % animal is suddenly displaced forward upon start of world display.
    
    vr = initializeTrialWorld(vr);
    if vr.protocol.endExperiment == true
      % Allow end of experiment only after completion of the last trial
      vr.experimentEnded  = true;
    elseif ~vr.experimentEnded
      vr.state            = BehavioralState.StartOfTrial;
      vr                  = teleportToStart(vr);
    end

    
  %========================================================================
  case BehavioralState.StartOfTrial
    % Broadcast trial configuration
    if ~isempty(vr.pager)
      info              = struct();
      info.trial        = [ vr.protocol.currentTrial  ...
                          , int8(vr.trialType)        ...
                          , vr.mazeID                 ...
                          ];
      info.start        = clock;
      info.start        = round(info.start(end-2:end));
      info.cue          = [];
%       info.cue          = vr.cuePos;
      vr.pager.command([], {}, {}, @IPPager.retryUntilNextCommand, 'i', info);
    end
    
    
    % Teleport to start and send signals indicating start of trial
    vr                  = startVRTrial(vr);
    prevDuration        = vr.logger.logStart(vr);
    vr.currentCue       = 0;
    vr.protocol.recordTrialDuration(prevDuration);
    
    vr.worlds{vr.currentWorld}.surface.visible  = vr.surfaceVisibility;
    
    
  %========================================================================
  case BehavioralState.WithinTrial
    % Broadcast behavior
    if ~isempty(vr.pager)
      vr.pager.broadcast([], 'p', vr.position([1 2 end]));
    end

    % Reset sound counter if no longer relevant
    if ~isempty(vr.soundStart) && toc(vr.soundStart) > vr.punishment.duration
      vr.soundStart       = [];
    end

    
    % Check if animal has met the trial violation criteria
    if isViolationTrial(vr)
      vr.choice           = Choice.nil;
      vr.state            = BehavioralState.ChoiceMade;
    
    % Check if animal has entered a choice region after it has entered an arm
    elseif vr.iArmEntry > 0
      for iChoice = 1:numel(vr.cross_choice)
        if isPastCrossing(vr.cross_choice{iChoice}, vr.position)
          vr.choice       = Choice(iChoice);
          vr.state        = BehavioralState.ChoiceMade;
          break;
        end
      end
      
    % Check if animal has entered the T-maze arms after the memory period
    elseif vr.iMemEntry > 0
      if isPastCrossing(vr.cross_arms, vr.position)
        vr.iArmEntry      = vr.iterFcn(vr.logger.iterationStamp(vr));
      end
      
    % Check if animal has entered the memory region after the cue period
    elseif vr.iCueEntry > 0 && isPastCrossing(vr.cross_memory, vr.position)
      vr.iMemEntry        = vr.iterFcn(vr.logger.iterationStamp(vr));
      
      % Turn off visibility of cues if so desired
      if ~isnan(vr.cueVisibleRange)
        vr.worlds{vr.currentWorld}.surface.visible([vr.tri_turnCue{vr.currentWorld,:}]) = false;
      end
    
    % If still in the start region, do nothing
    elseif vr.iCueEntry < 1 && ~isPastCrossing(vr.cross_cue, vr.position)
      
    % If in the cue region, make cues visible when the animal is close enough
    else
      if vr.iCueEntry < 1
        vr.iCueEntry      = vr.iterFcn(vr.logger.iterationStamp(vr));
      end
      
      % Cues are triggered only when animal is facing forward
      if abs(angleMPiPi(vr.position(end))) < pi/2
      % Loop through cues on both sides of the maze
      for iSide = 1:numel(ChoiceExperimentStats.CHOICES)
        triangles         = vr.tri_turnCue{vr.currentWorld,iSide};
        for iCue = 1:numel(vr.cuePos{iSide})
          % Compute distance to cue and whether or not it is in range
          cueDistance     = vr.cuePos{iSide}(iCue) - vr.position(2);
          inVisRange      = ( cueDistance <= vr.cueVisibleAt )                      ...
                         && ( isnan(vr.cueVisibleRange)                               ...
                           || (cueDistance >= vr.cueVisibleAt - vr.cueVisibleRange)   ...
                            );
          outVisRange     = ~isnan(vr.cueVisibleRange)                              ...
                         && (cueDistance <  vr.cueVisibleAt - vr.cueVisibleRange)   ...
                          ;

          % If moving far away from a visible cue, make it invisible in the
          % next iteration
              if ~vr.cueAppeared(iSide,iCue) && inVisRange
            % If approaching a cue and near enough, make it visible in the
            % next iteration
            vr.cueAppeared(iSide,iCue)                                    = true;
            vr.cueOnset{iSide}(iCue)                                      = vr.logger.iterationStamp(vr) + 1;
            vr.worlds{vr.currentWorld}.surface.visible(triangles(:,iCue)) = true;
            
%            UseSounds=0;
            if UseSounds
               if iSide==1
                   play(vr.left_sound.player);
               else
                   play(vr.right_sound.player);
               end                   
            end
            
            % Keep track of which side the last seen cue appears on
            vr.cueSign                                                    = -vr.cueSign;
            vr.currentCue                                                 = vr.cueSign * iSide;

              % If moving far away from a visible cue, make it invisible in the
              % next iteration
              elseif vr.cueAppeared(iSide,iCue) && outVisRange
            vr.worlds{vr.currentWorld}.surface.visible(triangles(:,iCue)) = false;
            if vr.cueOffset{iSide}(iCue) < 1
              vr.cueOffset{iSide}(iCue)                                   = vr.logger.iterationStamp(vr) + 1;
              vr.currentCue                                               = 0;
            end
          end
        end
      end
      end
    end
    
    
  %========================================================================
  case BehavioralState.ChoiceMade
    % Option where trial continues regardless even when the mouse is wrong
    if vr.enforceSuccess && vr.choice ~= vr.trialType
      vr.state        = BehavioralState.WithinTrial;
      % Still play aversive sound (if not already playing)
      if isempty(vr.soundStart) || toc(vr.soundStart) > vr.punishment.duration
        vr.soundStart = tic;
        play(vr.punishment.player);
      end
      
    % Otherwise take decision on the mouse's choice
    else
      % Log the end of the trial
      vr.excessTravel = vr.logger.distanceTraveled() - vr.mazeLength;
      vr.currentCue   = RigParameters.analogVRange(1);
      vr.logger.logEnd(vr);
    
      % Handle reward/punishment and end of trial pause
      vr = judgeVRTrial(vr);
    end
    
    
  %========================================================================
  case BehavioralState.DuringReward
    % This intermediate state is necessary so that whatever changes to the
    % ViRMen world upon rewarded behavior is applied before entering the
    % end of trial wait period
    vr = rewardVRTrial(vr, vr.rewardFactor);

    % For human testing, flash the screen green if correct and red if wrong
    if ~RigParameters.hasDAQ && ~RigParameters.simulationMode
      if vr.choice == vr.trialType
        vr.worlds{vr.currentWorld}.backgroundColor  = [0 1 0] * 0.8;
      elseif vr.choice == vr.wrongChoice
        vr.worlds{vr.currentWorld}.backgroundColor  = [1 0 0] * 0.8;
      else
        vr.worlds{vr.currentWorld}.backgroundColor  = [0 0.5 1] * 0.8;
      end
    end
    
    
  %========================================================================
  case BehavioralState.EndOfTrial
    % Send signals indicating end of trial and start inter-trial interval  
    vr = endVRTrial(vr);    

    
  %========================================================================
  case BehavioralState.InterTrial
    % Handle input of comments etc.
    vr.logger.logExtras(vr, vr.rewardFactor);
    vr.state    = BehavioralState.SetupTrial;
    if ~RigParameters.hasDAQ
      vr.worlds{vr.currentWorld}.backgroundColor  = [0 0 0];
    end
    
    % Record performance for the trial
    performance     = vr.protocol.recordChoice( vr.choice                                   ...
                                              , vr.rewardFactor * RigParameters.rewardSize  ...
                                              , vr.trialWeight                              ...
                                              , vr.excessTravel < vr.maxExcessTravel        ...
                                              , vr.logger.trialLength()                     ...
                                              , cellfun(@numel, vr.cuePos)                  ...
                                              );
    
    % Broadcast behavior
    if ~isempty(vr.pager)
      info              = struct();
      info.trial        = [ vr.protocol.currentTrial    ...
                            int8(vr.trialType)          ...
                            vr.choice == vr.trialType   ...
                          ];
      info.performance  = performance;
      info.reward       = vr.protocol.totalRewards;
      vr.pager.command([], {}, {}, @IPPager.retryUntilMaxTimes, 't', info);
    end

    % Decide duration of inter trial interval
    if vr.choice == vr.trialType
      vr.waitTime       = vr.itiCorrectDur;
    else
      vr.waitTime       = vr.itiWrongDur;
    end


    
  %========================================================================
  case BehavioralState.EndOfExperiment
    vr.experimentEnded  = true;
    
end
end                     % Only if not in time-out period


% IMPORTANT: Log position, velocity etc. at *every* iteration
vr.logger.logTick(vr, vr.mr.last_displacement);
vr.protocol.update();

% Send DAQ signals for multi-computer synchronization
updateDAQSyncSignals(vr, vr.protocol.currentTrial);


%****** DEBUG DISPLAY ******
if ~RigParameters.hasDAQ && ~RigParameters.simulationMode
  vr.text(1).string   = num2str(vr.cueCombo(1,:));
  vr.text(2).string   = num2str(vr.cueCombo(2,:));
  vr.text(3).string   = num2str(vr.slotPos(1,1:sum(vr.cueCombo(1,:))), '%4.0f ');
  vr.text(4).string   = num2str(vr.slotPos(2,1:sum(vr.cueCombo(2,:))), '%4.0f ');
end
%***************************

catch err
  displayException(err);
  keyboard
  vr.experimentEnded    = true;
end


%%_________________________________________________________________________
% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)

% Stop user control via statistics display
vr.protocol.stop();

% Log various pieces of information
if ~isempty(vr.logger.logFile)
  % Save via logger first to discard empty records
  log = vr.logger.save(true, vr.timeElapsed, vr.protocol.getPlots());
  
  vr.exper.userdata.regiment.recordBehavior(vr.exper.userdata.trainee, log, vr.logger.newBlocks);
  vr.exper.userdata.regiment.save();
end

% Standard communications shutdown
terminateVRRig(vr);



%%_________________________________________________________________________
% --- (Re-)triangulate world and obtain various subsets of interest
function vr = computeWorld(vr)

% Modify the ViRMen world to the specifications of the given maze; sets
% vr.mazeID to the given mazeID
vr                        = configureMaze(vr, vr.mazeID, vr.mainMazeID);
vr.mazeLength             = vr.lStart                                   ...
                          - vr.worlds{vr.currentWorld}.startLocation(2) ...
                          + vr.lCue                                     ...
                          + vr.lMemory                                  ...
                          + vr.lArm                                     ...
                          ;

% Specify parameters for computation of performance statistics
% (maze specific for advancement criteria)
criteria                  = vr.mazes(vr.mainMazeID).criteria;
if vr.warmupIndex > 0
  vr.protocol.setupStatistics(criteria.warmupNTrials(vr.warmupIndex), 1, false);
elseif isempty(criteria.demoteBlockSize)
  vr.protocol.setupStatistics(criteria.numTrials, 1, false);
else
  vr.protocol.setupStatistics(criteria.demoteBlockSize, criteria.demoteNumBlocks, true);
end


% Mouse is considered to have made a choice if it enters one of these areas
vr.cross_choice           = { getCrossingLine(vr, 'choiceLFloor', 1, @minabs)  ...
                            , getCrossingLine(vr, 'choiceRFloor', 1, @minabs)  ...
                            };

% Other regions of interest in the maze
vr.cross_cue              = getCrossingLine(vr, 'cueFloor'   , 2, @min);
vr.cross_memory           = getCrossingLine(vr, 'memoryFloor', 2, @min);
vr.cross_arms             = getCrossingLine(vr, 'armsFloor'  , 2, @min);

% Indices of left/right turn cues
turnCues                  = {'leftTurnCues', 'rightTurnCues'};
vr.tri_turnCue            = getVirmenFeatures('triangles', vr, turnCues{:});
vr.tri_turnHint           = getVirmenFeatures('triangles', vr, 'leftTurnHint', 'rightTurnHint' );
vr.vtx_turnCue            = getVirmenFeatures('vertices' , vr, turnCues{:});
vr.dynamicCueNames        = {'tri_turnCue'};
vr.choiceHintNames        = {'tri_turnHint'};

% HACK to deduce which triangles belong to which tower -- they seem to be
% ordered by column from empirical tests
for iChoice = 1:numel(vr.tri_turnCue)
  vr.tri_turnCue{iChoice} = reshape(vr.tri_turnCue{iChoice}, [], vr.nCueSlots);
  vr.vtx_turnCue{iChoice} = reshape(vr.vtx_turnCue{iChoice}, [], vr.nCueSlots);
end


% Cache various properties of the loaded world (maze configuration) for speed
vr                        = cacheMazeConfig(vr);
vr.cueIndex               = zeros(1, numel(turnCues));
vr.slotPos                = nan(numel(ChoiceExperimentStats.CHOICES), vr.nCueSlots);
for iChoice = 1:numel(turnCues)
  vr.cueIndex(iChoice)    = vr.worlds{vr.currentWorld}.objects.indices.(turnCues{iChoice});
  cueObject               = vr.exper.worlds{vr.currentWorld}.objects{vr.cueIndex(iChoice)};
  vr.slotPos(iChoice,:)   = cueObject.y;
end

% Set up Poisson stimulus train
lCue                      = str2double(vr.mazes(vr.mazeID).variable.lCue);
if vr.poissonStimuli.configure( lCue, vr.cueVisibleAt, vr.cueMeanCount, vr.cueProbability                ...
                              , vr.nCueSlots, vr.cueMinSeparation, vr.panSessionTrials  ...
                              , vr.FracEdgeTrials, vr.EdgeProbDef);
  % Save to disk in case of change
  vr.protocol.log('Saving Poisson stimuli bank to %s.', vr.stimulusBank);
  save(vr.stimulusBank, '-struct', 'vr', 'poissonStimuli');
end

curfold = [vr.exper.userdata.regiment.dataPath,'\data\',vr.exper.userdata.trainee.name];
filename1 = [vr.exper.userdata.regiment.dataPath,'\data\',vr.exper.userdata.trainee.name,'\',vr.exper.userdata.trainee.name,'_'];
curtime = floor(clock);
filename2 = [num2str(curtime(1)),'-',num2str(curtime(2)),'-',num2str(curtime(3)),'_',num2str(curtime(4)),'-',num2str(curtime(5)),'-',num2str(curtime(6))];
slashes = find(vr.exper.userdata.trainee.experiment=='\');

if ~exist(curfold,'dir')
    mkdir(curfold)
end
zip([filename1,filename2,'.zip'],vr.exper.userdata.trainee.experiment(1:slashes(end-1)-1));



%%_________________________________________________________________________
% --- Modify the world for the next trial
function vr = initializeTrialWorld(vr)

% Recompute world for the desired maze level if necessary
[vr, mazeChanged]         = decideMazeAdvancement(vr);
if mazeChanged
  vr                      = computeWorld(vr);
end

% Adjust the reward level 
if      ( mazeChanged && vr.warmupIndex < 1 )               ...
    ||  ( vr.protocol.currentTrial > vr.sampleNumTrials )
  vr.protocol.computeRewardScale(vr.prevPerformance, 1, 2, vr.itiCorrectDur, vr.itiWrongDur);
  if vr.mazeID>=10
        vr.protocol.setRewardScale(1.2, true);
  end
  vr.sampleNumTrials      = nan;
end


% Select a trial type, i.e. whether the correct choice is left or right
[success, vr.trialProb]   = vr.protocol.drawTrial(vr.mazeID);
vr.experimentEnded        = ~success;
vr.trialType              = Choice(vr.protocol);
vr.wrongChoice            = setdiff(ChoiceExperimentStats.CHOICES, vr.trialType);

% Flags for animal's progress through the maze
vr.iCueEntry              = vr.iterFcn(0);
vr.iMemEntry              = vr.iterFcn(0);
vr.iArmEntry              = vr.iterFcn(0);

% Modify ViRMen world object visibilities and colors 
vr                        = configureCues(vr);

% Cue presence on right and wrong sides
[vr, vr.trialWeight]      = drawCueSequence(vr);

% Visibility range of cues
vr.cueAppeared            = false(size(vr.cueCombo));

%%_________________________________________________________________________
% --- Draw a random cue sequence
function [vr, nonTrivial] = drawCueSequence(vr)

% Common storage
vr.cuePos                 = cell(size(ChoiceExperimentStats.CHOICES));
vr.cueOnset               = cell(size(ChoiceExperimentStats.CHOICES));
vr.cueOffset              = cell(size(ChoiceExperimentStats.CHOICES));
vr.cueSign                = 1;
vr.currentCue             = RigParameters.analogVRange(1);

% Obtain the next trial in the configured sequence, if available
trial                     = vr.poissonStimuli.nextTrial();
if isempty(trial)
  vr.experimentEnded      = true;
  nonTrivial              = false;
  return;
end

% Convert canonical [salient; distractor] format of cues to a side based
% representation
if vr.trialType == 1
  vr.cuePos               = trial.cuePos;
  vr.cueCombo             = trial.cueCombo;
else
  vr.cuePos               = flip(trial.cuePos);
  vr.cueCombo             = flipud(trial.cueCombo);
end
vr.nSalient               = trial.nSalient;
vr.nDistract              = trial.nDistract;
vr.trialID                = trial.index;

% Special case for nontrivial experiments -- only count trials with
% nontrivial cue distributions for performance display
nonTrivial                = isinf(vr.cueProbability)  ...
                         || (vr.nDistract >  0)       ...
                          ;

% Reposition cues according to the drawn positions
for iSide = 1:size(vr.cueCombo,1)
  vertices                  = vr.vtx_turnCue{vr.currentWorld, iSide};
  for iCue = 1:numel(vr.cuePos{iSide})
    vr.worlds{vr.currentWorld}.surface.vertices(2,vertices(:,iCue))                           ...
                            = vr.worlds{vr.currentWorld}.surface.vertices(2,vertices(:,iCue))   ...
                            + vr.cuePos{iSide}(iCue)                                            ...
                            - vr.slotPos(iSide,iCue)                                            ...
                            ;
    vr.slotPos(iSide,iCue)  = vr.cuePos{iSide}(iCue);
  end
  
  % Initialize times at which cues were turned on
  vr.cueOnset{iSide}        = zeros(size(vr.cuePos{iSide}), vr.iterStr);
  vr.cueOffset{iSide}       = zeros(size(vr.cuePos{iSide}), vr.iterStr);
end


%%_________________________________________________________________________
% --- Trial and reward configuration
function vr = setupTrials(vr)

% Global variables for remote control
global remoteSets;
remoteSets  = cell(0,2);

%--------------------------------------------------------------------------9/
% Sequence of progressively more difficult mazes; see docs for prepareMazes()
%________________________________________ 1 _________ 2 _________ 3 _________ 4 _________ 5 _________ 6 _________ 7 __________ 8 __________ 9 __________ 10 _________ 11 ________12_________13_______
mazes     = struct( 'lStart'          , {6         , 30        , 30        , 30        , 30        , 30        , 30         , 30         , 30         , 30         , 30         , 30         , 30         }   ...
                  , 'lCue'            , {40        , 60        , 100       , 150       , 230       , 230       , 230        , 230        , 230        , 230        , 230        , 230        , 250        }   ...
                  , 'lMemory'         , {5         , 5         , 20        , 20        , 20        , 20        , 20         , 20         , 20         , 20         , 20         , 20         , 20         }   ...
                  , 'tri_turnHint'    , {true      , true      , true      , true      , true      , false     , false      , false      , false      , false      , false      , false      , false      }   ...
                  , 'cueVisibleRange' , {nan       , nan       , nan       , nan       , nan       , nan       , nan        , nan        , inf        , 6          , 6          , 6          , 8          }   ...
                  , 'cueProbability'  , {inf       , inf       , inf       , inf       , inf       , inf       , 2.5        , 1.35       , 1.35       , 1.35       , 1          , 1.35       , 1.35       }   ...
                  , 'cueMeanCount'    , {4         , 4         , 5         , 7.5       , 7.5       , 7.5       , 7.5        , 7.5        , 7.5        , 7.5        , 7.5        , 7.5        , 7.5        }   ...
                  , 'FracEdgeTrials'  , {0         , 0         , 0         , 0         , 0         , 0         , 0          , 0          , 0.05       , 0.05       , 0.05       , 0.05       , 0.05       }   ...
                  , 'EdgeProbDef'     , {0.01      , 0.01      , 0.01      , 0.01      , 0.01      , 0.01      , 0.01       , 0.01       , 0.01       , 0.01       , 0.01       , 0.01       , 0.01       }   ...
                  );                                                                                                                                                      
% criteria  = struct( 'numTrials'       , {5         , 10        , 10        , 10        , 15        , 10        , 10         , 10         , 10         , 10         , 10         }   ...
%                   , 'numTrialsPerMin' , {0         , 0         , 0         , 0         , 3         , 3         , 3          , 3          , 3          , 3          , 3          }   ...
%                   , 'warmupNTrials'   , {[]        , []        , []        , []        , []        , 5         , [5   ,5   ], [5   ,5   ], [5   ,5   ], [5   ,5   ], [5   ,5   ]}   ...
%                   , 'demoteBlockSize' , {[]        , []        , []        , []        , []        , []        , []         , 10         , 10         , 10         , 10         }   ...
criteria  = struct( 'numTrials'       , {80        , 80        , 100       , 100       , 100       , 100       , 100        , 100        , 100        , 100        , 100        , 100        , 100        }   ...
                  , 'numTrialsPerMin' , {0         , 0         , 0         , 0         , 3         , 3         , 3          , 3          , 3          , 3          , 3          , 3          , 3          }   ...
                  , 'warmupNTrials'   , {[]        , []        , []        , []        , []        , 40        , [20  ,30  ], [20  ,30  ], [20  ,30  ], [15  ,15  ], [20  ,30 ] , [15  ,15 ] , [10  ,10 ] }   ...
                  , 'numSessions'     , {0         , 0         , 0         , 0         , 2         , 3         , 2          , 2          , 1          , 1          , 2          , 2          , 2          }   ...
                  , 'performance'     , {0         , 0         , 0.6       , 0.6       , 0.8       , 0.75      , 0.75       , 0.7        , 0.7        , 0.95       , 0.6        , 0.85       , 0.85       }   ...
                  , 'maxBias'         , {inf       , 0.2       , 0.2       , 0.2       , 0.15      , 0.15      , 0.15       , 0.15       , 0.15       , 0.15       , 0.2        , 0.15       , 0.15       }   ...
                  , 'warmupMaze'      , {[]        , []        , []        , []        , []        , 5         , [5   ,6   ], [5   ,7   ], [5   ,7   ], [5  ,  7], [5   ,7 ]    , [5   ,7 ]  , [5   ,7 ]  }   ...
                  , 'warmupPerform'   , {[]        , []        , []        , []        , []        , 0.8       , [0.85,0.8 ], [0.85,0.75], [0.85,0.75], [0.85,0.75], [0.85,0.75], [0.85,0.75], [0.85,0.75]}   ...
                  , 'warmupBias'      , {[]        , []        , []        , []        , []        , 0.2       , [0.1 ,0.15], [0.1 ,0.15], [0.1 ,0.15], [0.1 ,0.15], [0.1 ,0.15], [0.1 ,0.15], [0.1 ,0.15]}   ...
                  , 'warmupMotor'     , {[]        , []        , []        , []        , []        , 0         , [0.75,0.75], [0.75,0.75], [0.75,0.75], [0.75,0.75], [0.75,0.75]  , [0.5,0.5]  , [0.5,0.5]  }   ...
                  , 'demoteNumBlocks' , {[]        , []        , []        , []        , []        , []        , []         , 3          , 3          , 3          , 3          , 3          , 3          }   ...
                  , 'demoteBlockSize' , {[]        , []        , []        , []        , []        , []        , []         , 40         , 40         , 40         , 40         , 40         , 40         }   ...
                  , 'demotePerform'   , {nan       , nan       , nan       , nan       , nan       , nan       , nan        , 0.2        , 0.2        , 0.2        , 0.2        , 0.2        , 0.2        }   ...
                  , 'demoteBias'      , {nan       , nan       , nan       , nan       , nan       , nan       , nan        , 0.8        , 0.8        , 0.8        , 0.8        , 0.8        , 0.8        }   ...
                  );
vr        = prepareMazes(vr, mazes, criteria);

% Precompute maximum number of cue towers given the cue region length and
% minimum tower separation
cueMinSeparation      = str2double(vr.exper.variables.cueMinSeparation);
for iMaze = 1:numel(vr.mazes)
  vr.mazes(iMaze).variable.nCueSlots  = num2str(floor( str2double(vr.mazes(iMaze).variable.lCue)/cueMinSeparation ));
end

% Number and mixing of trials
vr.targetNumTrials    = eval(vr.exper.variables.targetNumTrials);
vr.trialDuplication   = eval(vr.exper.variables.trialDuplication);
vr.trialDispersion    = eval(vr.exper.variables.trialDispersion);
vr.panSessionTrials   = eval(vr.exper.variables.panSessionTrials);

% Nominal extents of world
vr.worldXRange        = eval(vr.exper.variables.worldXRange);
vr.worldYRange        = eval(vr.exper.variables.worldYRange);

% Trial violation criteria
vr.maxTrialDuration             = eval(vr.exper.variables.maxTrialDuration);
[vr.iterFcn,vr.iterStr,iterMax] = smallestUIntStorage(vr.maxTrialDuration / RigParameters.minIterationDT);
vr.iterRange                    = [-(vr.targetNumTrials + vr.panSessionTrials), ceil(iterMax/10)];

% DAQ sync initial values
% vr.currentCue                   = RigParameters.analogVRange(1);


% Special case with no animal -- only purpose is to return maze configuration
hasTrainee            = isfield(vr.exper.userdata, 'trainee');


%--------------------------------------------------------------------------

% Sound for aversive stimulus
vr.punishment         = loadSound('siren_6kHz_12kHz_1s.wav', 1.2);
vr.left_sound         = loadSound('left_100ms.wav', 1.2);
vr.right_sound        = loadSound('right_100ms.wav', 1.2);

% Logged variables
if hasTrainee
    vr.sensorMode         = vr.exper.userdata.trainee.virmenSensor;
    vr.frictionCoeff      = vr.exper.userdata.trainee.virmenFrictionCoeff;
end

% Configuration for logging etc.
cfg.label             = vr.exper.worlds{1}.name(1);
cfg.versionInfo       = { 'mazeVersion', 'codeVersion' };
cfg.mazeData          = { 'mazes' };
cfg.trialData         = { 'trialProb', 'trialType', 'choice', 'trialID'           ...
                        , 'cueCombo', 'cuePos', 'cueOnset', 'cueOffset'           ...
                        , 'iCueEntry', 'iMemEntry', 'iArmEntry', 'excessTravel'   ...
                        };
cfg.protocolData      = { 'rewardScale' };
cfg.blockData         = { 'mazeID', 'mainMazeID', 'sensorMode' };
cfg.totalTrials       = vr.targetNumTrials + vr.panSessionTrials;
cfg.savePerNTrials    = 1;
cfg.pollInterval      = eval(vr.exper.variables.logInterval);
cfg.repositoryLog     = '..\..\version.txt';

if hasTrainee
    cfg.animal          = vr.exper.userdata.trainee;
    cfg.logFile         = vr.exper.userdata.regiment.whichLog(vr.exper.userdata.trainee);
    cfg.sessionIndex    = vr.exper.userdata.trainee.sessionIndex;
end

% The following variables are refreshed each time a different maze level is loaded
vr.experimentVars     = { 'nCueSlots', 'poissonCues', 'cueMeanCount'            ...
                        , 'cueProbability', 'cueMinSeparation', 'cueVisibleAt'  ...
                        , 'cueVisibleRange','FracEdgeTrials', 'EdgeProbDef'     ...
                        , 'lStart', 'lCue', 'lMemory', 'lArm'                   ... for maze length
                        , 'maxExcessTravel'                                     ...
                        };

if ~hasTrainee
    return;
end

%--------------------------------------------------------------------------

% Statistics for types of trials and success counts
vr.protocol           = ChoiceExperimentStats(cfg.animal, cfg.label, cfg.totalTrials, numel(mazes));
vr.protocol.addDrawMethod('eradeTrial', 'pseudorandomTrial', 'leftOnlyTrial', 'rightOnlyTrial');
vr.protocol.plot(1 + ~RigParameters.hasDAQ);

vr.protocol.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
vr.protocol.log('    %s : %s, session %d', vr.exper.userdata.trainee.name, datestr(now), vr.exper.userdata.trainee.sessionIndex);
vr.protocol.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');



% Predetermine warmup and main mazes based on training history
[vr.mainMazeID, vr.mazeID, vr.warmupIndex, vr.prevPerformance]  ...
                      = getTrainingLevel(vr.mazes, vr.exper.userdata.trainee, vr.protocol);

% Setup reward scale factor according to whether there is a warmup sequence
if isempty(vr.mazes(vr.mainMazeID).criteria.warmupMaze)
  vr.sampleNumTrials  = eval(vr.exper.variables.sampleNumTrials);
  vr.protocol.log('Will use first %d trials to estimate median trial duration.', vr.sampleNumTrials);
else
  vr.sampleNumTrials  = nan;
end
if isnan(vr.prevPerformance)
  vr.protocol.setRewardScale(1.5, true);
else
  vr.protocol.setRewardScale(1.0, true);
end

% Logging of experimental data
vr.logger             = ExperimentLog(vr, cfg, vr.protocol);


% Poisson stimulus trains, some identical across sessions
vr.stimulusBank       = 'poisson_stimulus_trains_discrete.mat';
if exist(vr.stimulusBank, 'file')
  vr.protocol.log('Loading Poisson stimuli bank from %s.', vr.stimulusBank);
  bank                = load(vr.stimulusBank);
  vr.poissonStimuli   = bank.poissonStimuli;
  vr.poissonStimuli.setTrialMixing(vr.targetNumTrials, vr.trialDuplication, vr.trialDispersion);
else
  vr.poissonStimuli   = PoissonStimulusTrain_discrete(vr.targetNumTrials, vr.trialDuplication, vr.trialDispersion);
end
vr.protocol.log('Configured %d trials with duplication factor %.3g, mixed with %d pan-session trials from bank.', vr.targetNumTrials, vr.trialDuplication, vr.panSessionTrials);


% Streaming behavioral data and remote control
if isfield(vr.exper.userdata, 'pager')
  vr                  = registerBehavioralListeners(vr);
else
  vr.pager            = [];
end
