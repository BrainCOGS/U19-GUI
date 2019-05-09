function code = accumulating_towers
% accumulating_towers   Code for the ViRMEn experiment accumulating_towers.
%   code = accumulating_towers   Returns handles to the functions that ViRMEn
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

% Standard communications lines for VR rig
vr    = initializeVRRig(vr, vr.exper.userdata.trainee);

% Number and sequence of trials, reward level etc.
vr    = setupTrials(vr);

% Initialize standard state control variables
vr    = initializeGradedExperiment(vr);

if ~vr.experimentEnded
  % Load the first maze
  vr  = computeWorld(vr, vr.exper.userdata.trainee.mazeID);
  vr.worlds{vr.currentWorld}.surface.visible(:) = false;
end

%****** DEBUG DISPLAY ******
% vr.text(1).position     = [-1 0.7];
% vr.text(1).size         = 0.03;
% vr.text(1).color        = [1 1 0];
% vr.text(2).position     = [-1 0.65];
% vr.text(2).size         = 0.03;
% vr.text(2).color        = [1 1 0];
% vr.text(3).position     = [-1.6 0.9];
% vr.text(3).size         = 0.02;
% vr.text(3).color        = [1 1 0];
% vr.text(4).position     = [-1.6 0.85];
% vr.text(4).size         = 0.02;
% vr.text(4).color        = [1 1 0];
%***************************


%%_________________________________________________________________________
% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)
try

  
% Handle communications at a reduced frequency
if ~isempty(vr.pager)
%   vr.runCount   = vr.runCount + 1;
%   if vr.runCount >= 10
%     vr.runCount = 0;
    vr.pager.heartbeat();
%   end
end
  
  
% Do nothing if in a time-out period
vr  = processWaitTimes(vr);
if vr.waitTime > 0
  return;   % Still waiting
end

% Handle keyboard input
vr  = processKeypress(vr);
vr  = processRemoteControl(vr);

% Take action depending on the simulation state
switch vr.state
  
  %========================================================================
  case BehavioralState.SetupTrial
    % Configure world for the trial; this is done separately from 
    % StartOfTrial as it can take a long time and we want to teleport the
    % animal back to the start location only after this has been completed
    % and the Virmen engine can do whatever behind-the-scenes magic. If we
    % try to merge this step with StartOfTrial, animal motion can
    % accumulate during initialization and result in an artifact where the
    % animal is suddenly displaced forward upon start of world display.
    
    vr        = initializeTrialWorld(vr);
    if vr.experimentEnded
      return;
    end
    vr.state  = BehavioralState.StartOfTrial;

    
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
    vr = startVRTrial(vr);
    vr.logger.logStart(vr);
    
    
  %========================================================================
  case BehavioralState.WithinTrial
    % Log position and velocity per previously set up interval
    vr.logger.logTick(vr);
    vr.protocol.update();

    % Broadcast behavior
    if ~isempty(vr.pager)
      vr.pager.broadcast([], 'p', vr.position([1 2 end]));
    end

    
    % Reset sound counter if no longer relevant
    if ~isempty(vr.soundStart) && toc(vr.soundStart) > vr.punishment.duration
      vr.soundStart       = [];
    end
    
    % Check if animal has entered a choice region
    if vr.passedTMazeStem
      for iChoice = 1:numel(vr.rect_choice)
        if isInRectangle(vr.rect_choice{iChoice}, vr.position)
          vr.choice       = Choice(iChoice);
          vr.state        = BehavioralState.ChoiceMade;
          break;
        end
      end
      
    % Check if animal has entered memory region
    elseif isInRectangle(vr.rect_memory, vr.position)
      vr.passedTMazeStem  = true;
      
      % Turn off visibility of cues if so desired
      if ~isnan(vr.cueVisibleRange)
        vr.worlds{vr.currentWorld}.surface.visible([vr.tri_turnCue{vr.currentWorld,:}]) = false;
      end
    
    % If in the stem, make cues visible when the animal is close enough
    else
      if abs(angleMPiPi(vr.position(end))) > pi/2
        direction         = -1;
      else
        direction         = 1;
      end
      
      for iChoice = 1:numel(ChoiceExperimentStats.CHOICES)
        triangles         = vr.tri_turnCue{vr.currentWorld,iChoice};
        for iCue = 1:numel(vr.cuePos{iChoice})
          cueDistance     = direction * (vr.cuePos{iChoice}(iCue) - vr.position(2));
          % If moving far away from a visible cue, make it invisible
          if cueDistance < vr.backwardVis
            vr.worlds{vr.currentWorld}.surface.visible(triangles(:,iCue)) = false;
          elseif ~vr.cueAppeared(iChoice,iCue) && cueDistance > 0 && cueDistance < vr.forwardVis
            % If approaching a cue and near enough, make it visible
            vr.cueAppeared(iChoice,iCue)                                  = true;
            vr.cueTime{iChoice}(iCue)                                     = toc(vr.logger.lastPoll);
            vr.worlds{vr.currentWorld}.surface.visible(triangles(:,iCue)) = true;
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
        sound(vr.punishment.y, vr.punishment.Fs);
      end

    % Otherwise take decision on the mouse's choice
    else
      % Log the end of the trial
      vr.logger.logEnd(vr);
    
      % Handle reward/punishment and end of trial pause
      vr = judgeVRTrial(vr);
    end
    
    
  %========================================================================
  case BehavioralState.DuringReward
    % This intermediate state is necessary so that whatever changes to the
    % ViRMen world upon rewarded behavior is applied before entering the
    % end of trial wait period
    
    % Optionally compute a reward factor to encourage learning of difficult tasks
    if vr.maxRewardFactor > 1 && vr.nDistract >= vr.nSalient/2
      easiness        = (vr.nSalient - vr.nDistract) / (vr.nSalient + vr.nDistract);
      vr.rewardFactor = easiness + vr.maxRewardFactor*(1 - easiness);
    end
    vr = rewardVRTrial(vr, vr.rewardFactor);
    
  %========================================================================
  case BehavioralState.EndOfTrial
    % Send signals indicating end of trial and start inter-trial interval  
    vr = endVRTrial(vr);    

    % For human testing, flash the screen green if correct and red if wrong
    if ~RigParameters.hasDAQ
      if vr.choice == vr.trialType
        vr.worlds{vr.currentWorld}.backgroundColor  = [0 1 0] * 0.8;
      elseif vr.choice == vr.wrongChoice
        vr.worlds{vr.currentWorld}.backgroundColor  = [1 0 0] * 0.8;
      else
        vr.worlds{vr.currentWorld}.backgroundColor  = [0 0.5 1] * 0.8;
      end
    end
    
    
  %========================================================================
  case BehavioralState.InterTrial
    % Handle input of comments etc.
    vr.logger.logExtras(vr.rewardFactor);
    performance = vr.protocol.recordChoice(vr.choice, vr.rewardFactor * RigParameters.rewardSize, vr.trialWeight);
    vr.state    = BehavioralState.SetupTrial;
    if ~RigParameters.hasDAQ
      vr.worlds{vr.currentWorld}.backgroundColor  = [0 0 0];
    end
    
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

    
  %========================================================================
  case BehavioralState.EndOfExperiment
    vr.experimentEnded  = true;
    
end

% Communicate virtual world parameters to DAQ
updateDAQ_detailed(vr);


%****** DEBUG DISPLAY ******
% vr.text(1).string   = num2str(vr.cueCombo(1,:));
% vr.text(2).string   = num2str(vr.cueCombo(2,:));
% vr.text(3).string   = num2str(vr.slotPos(1,1:sum(vr.cueCombo(1,:))), '%4.0f ');
% vr.text(4).string   = num2str(vr.slotPos(2,1:sum(vr.cueCombo(2,:))), '%4.0f ');
%***************************

catch err
  displayException(err);
  keyboard
  vr.experimentEnded    = true;
end


%%_________________________________________________________________________
% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)

% Log various pieces of information
if isfield(vr, 'logger') && ~isempty(vr.logger.logFile)
  log = vr.logger.save(true);   % must do this first to discard empty records
  vr.exper.userdata.regiment.recordBehavior(vr.exper.userdata.trainee, log);
  vr.exper.userdata.regiment.save();
end

% Standard communications shutdown
terminateVRRig(vr);



%%_________________________________________________________________________
% --- (Re-)triangulate world and obtain various subsets of interest
function vr = computeWorld(vr, mazeID)

% Modify the ViRMen world to the specifications of the given maze
vr  = configureMaze(vr, mazeID, vr.mainMazeID);

% Mouse is considered to have made a choice if it enters one of these areas
vr.rect_choice            = { getRectangle(vr, 'choiceLFloor')  ...
                            , getRectangle(vr, 'choiceRFloor')  ...
                            };

% Mouse has exited the T-maze stem if it enters the memory region
vr.rect_memory            = getRectangle(vr, 'memoryFloor');

% Indices of left/right turn cues
turnCues                  = {'leftTurnCues', 'rightTurnCues'};
vr.tri_turnCue            = getVirmenFeatures('triangles', vr, turnCues{:});
vr.tri_turnHint           = getVirmenFeatures('triangles', vr, 'leftTurnHint', 'rightTurnHint' );
vr.vtx_turnCue            = getVirmenFeatures('vertices' , vr, turnCues{:});
vr.choiceHintNames        = {'tri_turnHint'};

% HACK to deduce which triangles belong to which cue -- they seem to be
% ordered by column from empirical tests
for iChoice = 1:numel(vr.tri_turnCue)
  vr.tri_turnCue{iChoice} = reshape(vr.tri_turnCue{iChoice}, [], vr.nCueSlots);
  vr.vtx_turnCue{iChoice} = reshape(vr.vtx_turnCue{iChoice}, [], vr.nCueSlots);
end

% Cache various properties of the loaded world (maze configuration) for speed
vr                        = cacheMazeConfig(vr, vr.orientationTargets);
vr.cueIndex               = zeros(1, numel(turnCues));
vr.slotPos                = nan(numel(ChoiceExperimentStats.CHOICES), vr.nCueSlots);
for iChoice = 1:numel(turnCues)
  vr.cueIndex(iChoice)    = vr.worlds{vr.currentWorld}.objects.indices.(turnCues{iChoice});
  cueObject               = vr.exper.worlds{vr.currentWorld}.objects{vr.cueIndex(iChoice)};
  vr.slotPos(iChoice,:)   = cueObject.y;
end
vr.slotInitPos            = vr.slotPos;

% Set up Poisson stimulus train if relevant
if vr.poissonCues
  lCue                    = str2double(vr.mazes(vr.mazeID).variable.lCue);
  if vr.poissonStimuli.configure( lCue, vr.cueMeanCount, vr.cueProbability                ...
                                , vr.nCueSlots, vr.cueMinSeparation, vr.panSessionTrials  ...
                                );
    % Save to disk in case of change
    fprintf('----<<<  Saving Poisson stimuli bank to %s\n', vr.stimulusBank);
    save(vr.stimulusBank, '-struct', 'vr', 'poissonStimuli');
  end
end


%%_________________________________________________________________________
% --- Modify the world for the next trial
function vr = initializeTrialWorld(vr)

% Recompute world for the desired maze level if necessary
if vr.mazeChange ~= 0
  vr                      = computeWorld(vr, vr.mazeID + vr.mazeChange);
  vr.mazeChange           = 0;
end

% Select a trial type, i.e. whether the correct choice is left or right
[success, vr.trialProb]   = vr.protocol.drawTrial(vr.mazeID);
vr.experimentEnded        = ~success;
vr.trialType              = Choice(vr.protocol);
vr.wrongChoice            = setdiff(ChoiceExperimentStats.CHOICES, vr.trialType);

% Flags for animal's progress through the maze
vr.passedTMazeStem        = false;


% Modify ViRMen world object visibilities and colors 
vr                        = configureCues(vr, vr.orientationTargets);

% Cue presence on right and wrong sides
[vr, vr.trialWeight]      = drawCueSequence(vr);

% Visibility range of cues
vr.cueAppeared            = false(size(vr.cueCombo));
vr.forwardVis             = vr.cueVisibleAt;
vr.backwardVis            = vr.cueVisibleAt - vr.cueVisibleRange;

% Turn off all cues -- animal has to trigger them by approaching
vr.worlds{vr.currentWorld}.surface.visible([vr.tri_turnCue{vr.currentWorld,:}]) = false;


%%_________________________________________________________________________
% --- Draw a random cue sequence
function [vr, nonTrivial] = drawCueSequence(vr)

% Common storage
vr.cuePos                   = cell(size(ChoiceExperimentStats.CHOICES));
vr.cueTime                  = cell(size(ChoiceExperimentStats.CHOICES));


if vr.poissonCues

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

else

  % Cue presence probabilities for right and wrong sides
  cueProb                   = repmat(1 - vr.cueProbability, numel(ChoiceExperimentStats.CHOICES), vr.nCueSlots);
  cueProb(vr.trialType,:)   = vr.cueProbability;
  vr.trialID                = 0;

  % Draw combinations of left/right cues depending on difficulty
  while true
    vr.cueCombo             = rand(size(cueProb)) < cueProb;
    % Make sure that the cue combination is legal
    vr.nSalient             = sum(vr.cueCombo(vr.trialType,:));
    vr.nDistract            = sum(sum(vr.cueCombo(vr.wrongChoice,:)));
    if vr.nDistract < vr.nSalient
      break;
    end
  end

  % Store positions of cues, being careful to use the canonical values
  for iSide = 1:size(vr.cueCombo,1)
    vr.cuePos{iSide}        = vr.slotInitPos(iSide, vr.cueCombo(iSide,:));
  end

  % Special case for nontrivial experiments -- only count trials with
  % nontrivial cue distributions for performance display
  nonTrivial                = (vr.cueProbability == 1)            ...
                           || (vr.nSalient       <  vr.nCueSlots) ...
                           || (vr.nDistract      >  0)            ...
                            ;

end


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
  vr.cueTime{iSide}         = nan(size(vr.cuePos{iSide}));
end


%%_________________________________________________________________________
% --- Trial and reward configuration
function vr = setupTrials(vr)
global remoteSets;
remoteSets  = cell(0,2);

% Sequence of progressively more difficult mazes; see docs for prepareMazes()
%_______________________________________ 1 _________ 2 _________ 3 _________ 4 _________ 5 _________ 6 _________ 7 _________ 8 _________ 9 _________ 10 ________ 11 ________ 12 ________ 13 ________ 14 ________ 15 ________ 16 ________ 17 ________ 18 ________ 19 ________ 20 ________ 21 ________ 22 ______ human _________
mazes = struct( 'lCue'            , {40        , 60        , 100       , 100       , 100       , 100       , 100       , 100       , 100       , 100       , 150       , 200       , 200       , 200       , 200       , 200       , 200       , 200       , 200       , 200       , 200       , 200       , 200       }   ...
              , 'nCueSlots'       , {3         , 3         , 5         , 5         , 5         , 5         , 5         , 5         , 5         , 5         , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       }   ...
              , 'cueMeanCount'    , {nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , 8         , 8         , 10        , 10        , 10        , 10        , 10        , 10        , 10        , 10        , 10        , 10        , 20        }   ...
              , 'cueProbability'  , {1         , 1         , 1         , 1         , 0.9       , 0.8       , 0.8       , 0.8       , 0.7       , 0.6       , inf       , inf       , inf       , inf       , inf       , 4         , 2.5       , 1.2       , 0.5       , 1.2       , 0.5       , 0.5       , 0.5       }   ...
              , 'cueVisibleRange' , {nan       , nan       , nan       , nan       , nan       , nan       , inf       , 10        , 10        , 10        , nan       , nan       , nan       , 8         , 6         , inf       , inf       , inf       , inf       , 6         , 6         , 4         , 2         }   ...
              , 'cueMinSeparation', {nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , nan       , 8         , 8         , 8         , 10        , 8         , 8         , 8         , 8         , 8         , 8         , 8         , 6         , 4         }   ...
              , 'lStart'          , {6         , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        , 30        }   ...
              , 'lMemory'         , {5         , 5         , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        , 20        }   ...
              , 'tri_turnHint'    , {true      , true      , true      , false     , false     , false     , false     , false     , false     , false     , true      , true      , false     , false     , false     , false     , false     , false     , false     , false     , false     , false     , false     }   ...
              );

% Last maze is for human testing on a laptop
if RigParameters.hasDAQ
  mazes(end)  = [];
end

vr    = prepareMazes(vr, mazes);
for iMaze = 1:numel(vr.mazes)
  if isnan(str2double(vr.mazes(iMaze).variable.nCueSlots))
    vr.mazes(iMaze).variable.poissonCues      = 'true';
    vr.mazes(iMaze).variable.nCueSlots        = num2str(ceil( str2double(vr.mazes(iMaze).variable.lCue)             ...
                                                            / str2double(vr.mazes(iMaze).variable.cueMinSeparation) ...
                                                        ));
  else
    vr.mazes(iMaze).variable.poissonCues      = 'false';
    vr.mazes(iMaze).variable.cueMinSeparation = vr.exper.variables.cueMinSeparation;
  end
end


%--------------------------------------------------------------------------
% Sound for aversive stimulus
vr.punishment         = loadSound('siren_6kHz_12kHz_1s.wav', 1.2);

% Poisson stimulus trains, some identical across sessions
vr.targetNumTrials    = eval(vr.exper.variables.targetNumTrials);
vr.trialDuplication   = eval(vr.exper.variables.trialDuplication);
vr.trialDispersion    = eval(vr.exper.variables.trialDispersion);
vr.panSessionTrials   = eval(vr.exper.variables.panSessionTrials);
vr.stimulusBank       = 'poisson_stimulus_trains.mat';
if exist(vr.stimulusBank, 'file')
  fprintf('---->>>  Loading Poisson stimuli bank from %s\n', vr.stimulusBank);
  bank                = load(vr.stimulusBank);
  vr.poissonStimuli   = bank.poissonStimuli;
  vr.poissonStimuli.setTrialMixing(vr.targetNumTrials, vr.trialDuplication, vr.trialDispersion);
else
  vr.poissonStimuli   = PoissonStimulusTrain(vr.targetNumTrials, vr.trialDuplication, vr.trialDispersion);
end
fprintf('---->>>  Configured %d trials with duplication factor %.3g, mixed with %d pan-session trials from bank\n', vr.targetNumTrials, vr.trialDuplication, vr.panSessionTrials);


% Logging of experimental data
cfg.label             = vr.exper.worlds{1}.name(1);
cfg.animal            = vr.exper.userdata.trainee;
cfg.versionInfo       = {'mazeVersion','codeVersion'};
cfg.mazeData          = {'mazes'};
cfg.trialData         = {'mazeID','trialProb','trialType','cueCombo','cuePos','cueTime','choice','trialID'};
cfg.totalTrials       = vr.targetNumTrials + vr.panSessionTrials;
cfg.savePerNTrials    = 1;
cfg.pollInterval      = eval(vr.exper.variables.logInterval);
cfg.repositoryLog     = '..\version.txt';

if isfield(vr.exper.userdata, 'regiment')
  cfg.logFile         = vr.exper.userdata.regiment.whichLog(vr.exper.userdata.trainee);
  cfg.sessionIndex    = vr.exper.userdata.trainee.sessionIndex;
  vr.logger           = ExperimentLog(vr, cfg);
end

% The following variables are refreshed each time a different maze level is loaded
vr.experimentVars     = {'nCueSlots','poissonCues','cueMeanCount','cueProbability','cueVisibleAt', 'cueVisibleRange', 'cueMinSeparation', 'maxRewardFactor', 'rewardScale', 'orientationTargets'};

% Statistics for types of trials and success counts
vr.protocol           = ChoiceExperimentStats(cfg.animal, cfg.label, cfg.totalTrials, numel(mazes));
vr.protocol.addDrawMethod('eradeTrial', 'pseudorandomTrial', 'leftOnlyTrial', 'rightOnlyTrial');
if ~isempty(cfg.animal.color)
  vr.protocol.plot(1 + ~RigParameters.hasDAQ);
end


% Streaming behavioral data and remote control
if isfield(vr.exper.userdata, 'pager')
  vr                  = registerBehavioralListeners(vr);
else
  vr.pager            = [];
end
