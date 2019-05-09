function code = tower_pursuit
% tower_pursuit   Code for the ViRMEn experiment tower_pursuit.
%   code = tower_pursuit   Returns handles to the functions that ViRMEn
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

fprintf('\n\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
fprintf('    %s : %s, session %d\n', vr.exper.userdata.trainee.name, date2str(TrainingRegiment.dateStamp()), vr.exper.userdata.trainee.sessionIndex);
fprintf('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');



% Standard communications lines for VR rig
vr    = initializeVRRig(vr, vr.exper.userdata.trainee);

% Number and sequence of trials, reward level etc.
vr    = setupTrials(vr);

% Initialize standard state control variables
vr    = initializeGradedExperiment(vr);

if ~vr.experimentEnded
  % Load the first maze
  vr  = computeWorld(vr, vr.mazeID);
end

% Online display of performance statistics
vr.protocol.plot(1 + ~RigParameters.hasDAQ);


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
  
% Handle keyboard, remote input, wait times
vr  = processKeypress(vr, vr.protocol);
vr  = processRemoteControl(vr);
vr  = processWaitTimes(vr);
vr.prevState  = vr.state;


% Forced termination
if vr.protocol.endExperiment ~= false
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
    
    vr          = initializeTrialWorld(vr);
    if ~vr.experimentEnded
      vr.state  = BehavioralState.StartOfTrial;
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
    vr = startVRTrial(vr, vr.startLocation);
    prevDuration        = vr.logger.logStart(vr);
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

    
    % Check if animal has entered the target
    if sum((vr.position(1:2) - vr.targetLocation(1:2)).^2) < vr.targetRadius2
      vr.choice           = vr.trialType;
      vr.state            = BehavioralState.ChoiceMade;
    end
    
    
  %========================================================================
  case BehavioralState.ChoiceMade
    
    % Log the end of the trial
    vr.logger.logEnd(vr);

    % Handle reward/punishment and end of trial pause
    vr = judgeVRTrial(vr, false, vr.doTeleport);
    
    
  %========================================================================
  case BehavioralState.DuringReward
    % This intermediate state is necessary so that whatever changes to the
    % ViRMen world upon rewarded behavior is applied before entering the
    % end of trial wait period
    play(vr.rewardCue.player);
    vr = rewardVRTrial(vr, vr.rewardFactor);

    
  %========================================================================
  case BehavioralState.EndOfTrial
    % Send signals indicating end of trial and start inter-trial interval  
    vr = endVRTrial(vr, vr.doTeleport);
    
    
  %========================================================================
  case BehavioralState.InterTrial
    % Handle input of comments etc.
    vr.logger.logExtras(vr, vr.rewardFactor);
    performance = vr.protocol.recordChoice(vr.choice, vr.rewardFactor * RigParameters.rewardSize);
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
end                     % Only if not in time-out period


% IMPORTANT: Log position, velocity etc. at *every* iteration
vr.logger.logTick(vr, vr.mr.last_displacement);
vr.protocol.update();

% Send DAQ signals for multi-computer synchronization
updateDAQSyncSignals(vr, vr.protocol.currentTrial);


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

% Stop user control via statistics display
vr.protocol.stop();

% Log various pieces of information
if isfield(vr, 'logger') && ~isempty(vr.logger.logFile)
  % Save via logger first to discard empty records
  log = vr.logger.save(true, vr.timeElapsed, vr.protocol.getPlots());
  
  vr.exper.userdata.regiment.recordBehavior(vr.exper.userdata.trainee, log, vr.logger.newBlocks);
  vr.exper.userdata.regiment.save();
end

% Standard communications shutdown
terminateVRRig(vr);



%%_________________________________________________________________________
% --- (Re-)triangulate world and obtain various subsets of interest
function vr = computeWorld(vr, mazeID)

% Modify the ViRMen world to the specifications of the given maze; sets
% vr.mazeID to the given mazeID
vr                = configureMaze(vr, mazeID, vr.mainMazeID);
if vr.doTeleport
  vr.trialEndPauseDur = eval(vr.exper.variables.trialEndPauseDuration);
  vr.itiCorrectDur    = eval(vr.exper.variables.interTrialCorrectDuration);
  vr.itiWrongDur      = eval(vr.exper.variables.interTrialWrongDuration);
else
  vr.trialEndPauseDur = 0;
  vr.itiCorrectDur    = 0;
  vr.itiWrongDur      = 0;
end

% Indices of target
[vr.vtx_target, vr.idx_target]  = getVirmenFeatures('vertices' , vr, 'cueTower+cueTarget');

% Cache various properties of the loaded world (maze configuration) for speed
vr                = cacheMazeConfig(vr);
border            = eval(vr.exper.variables.border);
wArena            = eval(vr.exper.variables.wArena);
lArena            = eval(vr.exper.variables.lArena);
vr.arenaXMin      = -0.5*wArena +   border;
vr.arenaYMin      = -0.5*lArena +   border;
vr.arenaXRange    =      wArena - 2*border;
vr.arenaYRange    =      lArena - 2*border;
vr.targetRadius2  = eval(vr.exper.variables.rTarget)^2;

cueObject         = vr.exper.worlds{vr.currentWorld}.objects{vr.idx_target{vr.currentWorld,1,1}};
vr.targetPos      = [cueObject.x, cueObject.y];


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

% Modify ViRMen world object visibilities and colors 
vr                        = configureCues(vr);


orientRange               = str2double(vr.mazes(vr.mazeID).variable.orientRange);
vr.cuePos                 = cell(size(ChoiceExperimentStats.CHOICES));
while isempty(vr.cuePos{vr.trialType})
  
  % Generate random target location
  vr.targetLocation       = [ vr.arenaXMin + rand() * vr.arenaXRange    ...
                            , vr.arenaYMin + rand() * vr.arenaYRange    ...
                            ];

  % If teleportation is desired, animal starts out with a random position and
  % orientation relative to the target
  if vr.doTeleport
    animalLocation          = [ vr.arenaXMin + rand() * vr.arenaXRange    ...
                              , vr.arenaYMin + rand() * vr.arenaYRange    ...
                              , vr.position(3)                            ... z is inherited
                              , -orientRange + rand() * 2*orientRange     ...
                              ];
  else
    animalLocation          = vr.position;
  end

  % Enforce minimum distance between animal and target
  relTargetLoc              = vr.targetLocation(1:2) - animalLocation(1:2);
  targetDistance            = norm(relTargetLoc);
  if targetDistance < vr.minTargetDistance
    vr.targetLocation       = animalLocation(1:2) + relTargetLoc * vr.minTargetDistance / targetDistance;
  end
  
  % In case this is not possible within the confines of the world, redraw
  if      abs(vr.targetLocation(1)) > abs(vr.arenaXMin)   ...
      ||  abs(vr.targetLocation(2)) > abs(vr.arenaYMin)
    continue;
  end
  vr.cuePos{vr.trialType} = vr.targetLocation;
  

  % If teleportation is desired, orientation is relative to the target
  if vr.doTeleport
    targetAngle             = atan2(-relTargetLoc(1), relTargetLoc(2));
    animalLocation(end)     = animalLocation(end) + targetAngle;
    vr.startLocation        = animalLocation;
  else
    vr.startLocation        = [];
  end

end


% Reposition target cues according to the drawn position
vertices                  = vr.vtx_target{vr.currentWorld};
for iCoord = 1:2
  vr.worlds{vr.currentWorld}.surface.vertices(iCoord,vertices)                            ...
                          = vr.worlds{vr.currentWorld}.surface.vertices(iCoord,vertices)  ...
                          + vr.targetLocation(iCoord)                                     ...
                          - vr.targetPos(iCoord)                                          ...
                          ;
end
vr.targetPos              = vr.targetLocation;



%%_________________________________________________________________________
% --- Trial and reward configuration
function vr = setupTrials(vr)

% Global variables for remote control
global remoteSets;
remoteSets  = cell(0,2);

%--------------------------------------------------------------------------
% Sequence of progressively more difficult mazes; see docs for prepareMazes()
%________________________________________ 1 _________ 2 _________ 3 ______________
mazes     = struct( 'rCue'            , {20        , 5         , 2         }   ...
                  , 'rTarget'         , {80        , 15        , 10        }   ...
                  , 'orientRange'     , {pi/3      , pi        , 2*pi      }   ...
                  );
vr        = prepareMazes(vr, mazes);

% Special case with no animal -- only purpose is to return maze configuration
if ~isfield(vr.exper.userdata, 'trainee')
  return;
end

vr.mainMazeID         = vr.exper.userdata.trainee.mainMazeID;
vr.mazeID             = vr.mainMazeID;

                    
%--------------------------------------------------------------------------
% Sound for reward cue
vr.rewardCue          = loadSound('trill_6k_5k_10k.wav');

% Logging of experimental data
cfg.label             = vr.exper.worlds{1}.name(1);
cfg.animal            = vr.exper.userdata.trainee;
cfg.versionInfo       = {'mazeVersion','codeVersion'};
cfg.mazeData          = {'mazes'};
cfg.trialData         = {'trialType','choice','rewardScale','startLocation','cuePos'};
cfg.blockData         = {'mazeID','mainMazeID'};
cfg.totalTrials       = 500;
cfg.savePerNTrials    = 1;
cfg.pollInterval      = eval(vr.exper.variables.logInterval);
cfg.repositoryLog     = '..\..\version.txt';

if isfield(vr.exper.userdata, 'regiment')
  cfg.logFile         = vr.exper.userdata.regiment.whichLog(vr.exper.userdata.trainee);
  cfg.sessionIndex    = vr.exper.userdata.trainee.sessionIndex;
  vr.logger           = ExperimentLog(vr, cfg);
end

% Nominal extents of world
vr.worldXRange        = [-1 1] * eval(vr.exper.variables.wArena);
vr.worldYRange        = [-1 1] * eval(vr.exper.variables.lArena);
vr.iterRange          = [-500, 1000];
vr.currentCue         = 0;

% The following variables are refreshed each time a different maze level is loaded
vr.experimentVars     = {'rTarget','rewardScale','doTeleport','minTargetDistance'};

% Statistics for types of trials and success counts
vr.protocol           = ChoiceExperimentStats(cfg.animal, cfg.label, cfg.totalTrials, numel(mazes));
vr.protocol.addDrawMethod('eradeTrial', 'pseudorandomTrial', 'leftOnlyTrial', 'rightOnlyTrial');


% Streaming behavioral data and remote control
if isfield(vr.exper.userdata, 'pager')
  vr                  = registerBehavioralListeners(vr);
else
  vr.pager            = [];
end
