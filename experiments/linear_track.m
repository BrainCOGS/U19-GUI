function code = linear_track
% linear_track   Code for the ViRMEn experiment linear_track.
%   code = linear_track   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT



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


%%_________________________________________________________________________
% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)

% Do nothing if in a time-out period
vr  = processWaitTimes(vr);
if vr.waitTime > 0
  return;   % Still waiting
end

% Handle keyboard input
vr  = processKeypress(vr);


% Take action depending on the simulation state
switch vr.state
  
  %========================================================================
  case BehavioralState.StartOfTrial
    % Configure world for the trial
    vr = initializeTrialWorld(vr);
    if vr.experimentEnded
      return;
    end
    
    % Teleport to start and send signals indicating start of trial
    vr = startVRTrial(vr);
    vr.logger.logStart(vr);

    % Flag that animal has not exited sandbox region
    vr.choice = Choice.nil;
    
    
  %========================================================================
  case BehavioralState.WithinTrial
    % Log position and velocity per previously set up interval
    vr.logger.logTick(vr);
    vr.protocol.update();

    % Check if the animal has exited the sandbox for the first time
    if vr.choice == Choice.nil && ~isInRectangle(vr.rect_sandbox, vr.position)
      vr.choice   = Choice.L;
%       fprintf('OUT OUT OUT OUT OUT OUT OUT OUT OUT OUT OUT OUT OUT \n');

    % Check if animal has entered the goal
    elseif isInRectangle(vr.rect_goal, vr.position)
      vr.state    = BehavioralState.ChoiceMade;
      
    % If the animal has turned around, flag the trial as a failure
    elseif vr.choice == Choice.L && abs(angleMPiPi(vr.position(end))) > pi/2
      vr.choice   = Choice.R;
%       fprintf('TURNED TURNED TURNED TURNED TURNED TURNED TURNED TURNED TURNED \n');
    end
    
    
  %========================================================================
  case BehavioralState.ChoiceMade

    % Log the choice and end of the trial
    vr.logger.logEnd(vr);
    vr.protocol.recordChoice(vr.choice, RigParameters.rewardSize);

    % Handle reward/punishment and end of trial pause
    vr = judgeVRTrial(vr, true);
    
    
  %========================================================================
  case BehavioralState.DuringReward
    % This intermediate state is necessary so that whatever changes to the
    % ViRMen world upon rewarded behavior is applied before entering the
    % end of trial wait period
    vr = rewardVRTrial(vr);    
    
  %========================================================================
  case BehavioralState.EndOfTrial
    % Send signals indicating end of trial and start inter-trial interval  
    vr = endVRTrial(vr);    
    
    
  %========================================================================
  case BehavioralState.InterTrial
    % Handle input of comments etc.
    vr.logger.logExtras(1);
    
    vr.state  = BehavioralState.StartOfTrial;

    
  %========================================================================
  case BehavioralState.EndOfExperiment
    vr.experimentEnded  = true;
    
end

% Communicate virtual world parameters to DAQ
updateDAQ_detailed(vr);



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
vr  = configureMaze(vr, mazeID);

% Mouse is considered to have made a choice if it enters one of these areas
vr.rect_goal    = getRectangle(vr, 'goalFloor');
vr.rect_sandbox = getRectangle(vr, 'sandboxFloor');

% Cache various properties of the loaded world (maze configuration), for speed.
vr  = cacheMazeConfig(vr);



%%_________________________________________________________________________
% --- Modify the world for the next trial
function vr = initializeTrialWorld(vr)

% If we have completed a number of trials, check if there are enough
% consecutive correct trials to advance the maze
if          vr.protocol.currentTrial > 0                                      ...
        &&  vr.protocol.consecCorrect(vr.trialType, vr.protocol.currentTrial) ...
                      >= vr.nConsecToAdvance                                  ...
        &&  vr.mazeID < numel(vr.mazes)
  vr.mazeChange       = 1;
% It is also possible to demote the animal if it is always wrong
elseif      vr.protocol.currentTrial > 0                                      ...
        &&  vr.protocol.consecWrong(vr.trialType, vr.protocol.currentTrial)   ...
                      >= 10*vr.nConsecToAdvance                               ...
        &&  vr.mazeID > 1
  vr.mazeChange       = -1;
end

% Recompute world for the desired maze level if necessary
if vr.mazeChange ~= 0
  vr                  = computeWorld(vr, vr.mazeID + vr.mazeChange);
  vr.mazeChange       = 0;
end

% HACK:  Linear track is always a "left" choice
if ~vr.protocol.newTrial(vr.mazeID, Choice.L)
  vr.experimentEnded  = true;
end
vr.trialType          = Choice(vr.protocol);
vr.wrongChoice        = Choice.R;


% Modify ViRMen world object visibilities and colors 
vr                    = configureCues(vr);



%%_________________________________________________________________________
% --- Trial and reward configuration
function vr = setupTrials(vr)

% Success criteria
vr.nConsecToAdvance   = eval(vr.exper.variables.nConsecutiveToAdvance);

% Sequence of progressively more difficult mazes; see docs for prepareMazes()
baseLength            = eval(vr.exper.variables.lTrack);
maxLength             = eval(vr.exper.variables.lTrackMax);
sfLength              = eval(vr.exper.variables.lTrackSF);
nMazes                = ceil(( log(maxLength) - log(baseLength) )/log(sfLength));
mazeLengths           = baseLength * sfLength .^ (0:nMazes);
mazes                 = struct('lTrack', num2cell(mazeLengths));
vr                    = prepareMazes(vr, mazes);

% Logging of experimental data
cfg.label             = vr.exper.worlds{1}.name(1);
cfg.animal            = vr.exper.userdata.trainee;
cfg.logFile           = vr.exper.userdata.regiment.whichLog(vr.exper.userdata.trainee);
cfg.sessionIndex      = vr.exper.userdata.trainee.sessionIndex;
cfg.versionInfo       = {'mazeVersion','codeVersion'};
cfg.mazeData          = {'mazes'};
cfg.trialData         = {'mazeID','trialType','choice'};
cfg.savePerNTrials    = 1;
cfg.totalTrials       = 500;
cfg.pollInterval      = eval(vr.exper.variables.logInterval);
cfg.repositoryLog     = '..\version.txt';
vr.logger             = ExperimentLog(vr, cfg);
  
% Statistics for types of trials and success counts
vr.experimentVars     = {};
vr.protocol           = ChoiceExperimentStats(cfg.animal, cfg.label, cfg.totalTrials, numel(mazes));
vr.protocol.plot(1 + ~RigParameters.hasDAQ);
