function code = poisson_strips
% poisson_towers   Code for the ViRMEn experiment poisson_towers.
%   code = poisson_towers   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.

  % Begin header code - DO NOT EDIT
  code.initialization = @initializationCodeFun;
  code.runtime        = @runtimeCodeFun;
  code.termination    = @terminationCodeFun;
  % End header code - DO NOT EDIT

  code.setup          = @setupTrials;

end


%%_________________________________________________________________________
% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)

  % Number and sequence of trials, reward level etc.
  vr    = setupTrials(vr);

  % Standard communications lines for VR rig
  vr    = initializeVRRig(vr, vr.exper.userdata.trainee);

  % Initialize standard state control variables
  vr    = initializeGradedExperiment(vr);


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

end


%%_________________________________________________________________________
% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)
try

  % Handle keyboard, remote input, wait times
  vr  = processKeypress(vr, vr.protocol);
  if vr.waitTime ~= 0
    [vr.waitStart, vr.waitTime] = processWaitTimes(vr.waitStart, vr.waitTime);
  end
  vr.prevState  = vr.state;

    
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

      vr                    = initializeTrialWorld(vr);
      if vr.protocol.endExperiment == true
        % Allow end of experiment only after completion of the last trial
        vr.experimentEnded  = true;
      elseif ~vr.experimentEnded
        vr.state            = BehavioralState.InitializeTrial;
        vr                  = teleportToStart(vr);
      end
      

    %========================================================================
    case BehavioralState.InitializeTrial
      % Teleport to start and send signals indicating start of trial
      vr                    = teleportToStart(vr);
      vr                    = startVRTrial(vr);
      prevDuration          = vr.logger.logStart(vr);
      vr.protocol.recordTrialDuration(prevDuration);

      % Make the world visible
      vr.state              = BehavioralState.StartOfTrial;
      vr.worlds{vr.currentWorld}.surface.visible = vr.defaultVisibility;


    %========================================================================
    case BehavioralState.StartOfTrial
      % We keep the animal at the start of the track for the first iteration of the trial where 
      % the world is actually visible. This is only as a safety factor in case the first rendering
      % (caching) of the world graphics makes the previous iteration take unusually long, in which
      % case displacement is accumulated without the animal actually responding to anything.
      vr.state              = BehavioralState.WithinTrial;
      vr                    = teleportToStart(vr);

      
    %========================================================================
    case BehavioralState.WithinTrial
      % Reset sound counter if no longer relevant
      if ~isempty(vr.soundStart) && toc(vr.soundStart) > vr.punishment.duration
        vr.soundStart       = [];
      end

              
      % If a cue is already on, turn it off if enough time has elapsed
      for iSide = 1:numel(ChoiceExperimentStats.CHOICES)
        if vr.timeElapsed - vr.currentCueTime(iSide) >= vr.cueDuration
          triangles                   = vr.tri_turnCue(iSide,:);
          vr.cueOffset{iSide}(vr.currentCueIndex(iSide))            ...
                                      = vr.logger.iterationStamp(vr) + 1;
          vr.worlds{vr.currentWorld}.surface.visible(triangles)     ...
                                      = false;
          vr.currentCueTime(iSide)    = nan;
          vr.currentCueIndex(iSide)   = nan;
        end
      end
  

      %------------------------------------------------------------------------
      % Check if animal has met the trial violation criteria
      if isViolationTrial(vr)
        vr.choice           = Choice.nil;
        vr.state            = BehavioralState.ChoiceMade;

      %------------------------------------------------------------------------
      % Check if animal has entered a choice region after it has entered an arm
      elseif vr.iArmEntry > 0
        for iChoice = 1:numel(vr.cross_choice)
          if isPastCrossing(vr.cross_choice(iChoice), vr.position)
            vr.choice       = Choice(iChoice);
            vr.state        = BehavioralState.ChoiceMade;
            break;
          end
        end

      %------------------------------------------------------------------------
      % Check if animal has entered the T-maze arms after the memory period
      elseif vr.iMemEntry > 0
        if isPastCrossing(vr.cross_arms, vr.position)
          vr.iArmEntry      = vr.iterFcn(vr.logger.iterationStamp(vr));
        end

      %------------------------------------------------------------------------
      % Check if animal has entered the memory region after the cue period
      elseif vr.iCueEntry > 0 && isPastCrossing(vr.cross_memory, vr.position)
        vr.iMemEntry        = vr.iterFcn(vr.logger.iterationStamp(vr));
        
      %------------------------------------------------------------------------
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
            % If the cue is not on, check if we should turn it on
            if isnan(vr.currentCueTime(iSide))
              % Find nearest non-triggered cue
              isTriggered   = ~vr.cueAppeared{iSide}                    ...
                            & (vr.cuePos{iSide} - vr.position(2) < 0)   ...
                            ;
              iCue          = find(isTriggered, 1, 'first');
              if ~isempty(iCue)
                triangles                   = vr.tri_turnCue(iSide,:);
                vr.currentCueTime(iSide)    = vr.timeElapsed;
                vr.currentCueIndex(iSide)   = iCue;
                vr.cueAppeared{iSide}(iCue) = true;
                vr.cueOnset{iSide}(iCue)    = vr.logger.iterationStamp(vr);
                vr.worlds{vr.currentWorld}.surface.visible(triangles)   ...
                                            = true;
              end              
            end
          end
        end
      end


    %========================================================================
    case BehavioralState.ChoiceMade
      % Log the end of the trial
      vr.excessTravel = vr.logger.distanceTraveled() / vr.mazeLength - 1;
      vr.logger.logEnd(vr);

      % Handle reward/punishment and end of trial pause
      vr = judgeVRTrial(vr);

      % Update movement data display
      rawVel      = double(vr.logger.currentTrial.sensorDots(1:vr.logger.currentTrial.iterations, [4 3]));
      vr.protocol.updateRun ( vr.logger.currentTrial.position       ...
                            , vr.logger.currentTrial.velocity       ...
                            , atan2(-rawVel(:,1).*sign(rawVel(:,2)), abs(rawVel(:,2)))   ... HACK: bottom sensor specific!
                            );



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
      vr.protocol.recordChoice( vr.choice                                   ...
                              , vr.rewardFactor * RigParameters.rewardSize  ...
                              , vr.trialWeight                              ...
                              , vr.excessTravel < vr.maxExcessTravel        ...
                              , vr.logger.trialLength()                     ...
                              , cellfun(@numel, vr.cuePos)                  ...
                              );

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
  end                       % Only if not in time-out period

  
  % IMPORTANT: Log position, velocity etc. at *every* iteration
  vr.logger.logTick(vr, vr.sensorData);
  vr.protocol.update();

  % Send DAQ signals for multi-computer synchronization
  updateDAQSyncSignals(vr, vr.protocol.currentTrial, vr.logger.iterationStamp(vr));


  %****** DEBUG DISPLAY ******
  if ~RigParameters.hasDAQ && ~RigParameters.simulationMode
    vr.text(1).string   = num2str(vr.cueCombo(1,:));
    vr.text(2).string   = num2str(vr.cueCombo(2,:));
  end
  %***************************

  
catch err
  displayException(err);
  keyboard
  vr.experimentEnded    = true;
end
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

end


%%_________________________________________________________________________
% --- (Re-)triangulate world and obtain various subsets of interest
function vr = computeWorld(vr)

  % Modify the ViRMen world to the specifications of the given maze; sets
  % vr.mazeID to the given mazeID
  [vr,lCue,stimParameters]  = configureMaze(vr, vr.mazeID, vr.mainMazeID);
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
  else
    vr.protocol.setupStatistics(criteria.numTrials, 1, false);
  end


  % Mouse is considered to have made a choice if it enters one of these areas
  vr.cross_choice           = getCrossingLine(vr, {'choiceLFloor', 'choiceRFloor'}, 1, @minabs);

  % Other regions of interest in the maze
  vr.cross_cue              = getCrossingLine(vr, {'cueFloor'}   , 2, @min);
  vr.cross_memory           = getCrossingLine(vr, {'memoryFloor'}, 2, @min);
  vr.cross_arms             = getCrossingLine(vr, {'armsFloor'}  , 2, @min);

  % Indices of left/right turn cues
  turnCues                  = {'leftTurnCue', 'rightTurnCue'};
  vr.tri_turnCue            = getVirmenFeatures('triangles', vr, turnCues);
  vr.tri_turnHint           = getVirmenFeatures('triangles', vr, {'leftTurnHint', 'rightTurnHint'} );
  vr.tri_hintOff            = getVirmenFeatures('triangles', vr, {'leftHintOff' , 'rightHintOff' } );
  vr.vtx_turnCue            = getVirmenFeatures('vertices' , vr, turnCues);
  vr.dynamicCueNames        = {'tri_turnCue'};
  vr.choiceHintNames        = {'tri_turnHint'};


  % Cache various properties of the loaded world (maze configuration) for speed
  vr                        = cacheMazeConfig(vr);
  
  % Get list of parameters that the stimulus configuration depends on
  stimParameters            = cell(size(vr.stimulusParameters));
  for iParam = 1:numel(vr.stimulusParameters)
    stimParameters{iParam}  = vr.(vr.stimulusParameters{iParam});
  end

  % Set up Poisson stimulus train
  lCue                      = str2double(vr.mazes(vr.mazeID).variable.lCue);
  if vr.poissonStimuli.configure(lCue, stimParameters{:});
    warndlg( sprintf('Stimuli parameters had to be configured for maze %d. Continue?', vr.mazeID));
  
%     if strcmp(choice, 'No')
%       vr.experimentEnded    = true;
%       return;
%     end

    % Save to disk in case of change
    vr.protocol.log('Saving Poisson stimuli bank to %s.', vr.stimulusBank);
    save(vr.stimulusBank, '-struct', 'vr', 'poissonStimuli');
  end

end


%%_________________________________________________________________________
% --- Modify the world for the next trial
function vr = initializeTrialWorld(vr)

  % Recompute world for the desired maze level if necessary
  [vr, mazeChanged]         = decideMazeAdvancement(vr, vr.numMazesInProtocol);
  if mazeChanged
    vr                      = computeWorld(vr);
    
    % The recomputed world should remain invisible until after the ITI
    vr.worlds{vr.currentWorld}.surface.visible(:) = false;
  end

  % Adjust the reward level 
  if mazeChanged
    vr.protocol.updateRewardScale(vr.warmupIndex, vr.mazeID);
  end


  % Select a trial type, i.e. whether the correct choice is left or right
  [success, vr.trialProb]   = vr.protocol.drawTrial(vr.mazeID, [-vr.lStart, vr.lCue + vr.lMemory + 40]);
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
  vr.currentCueTime         = nan(size(ChoiceExperimentStats.CHOICES));
  vr.currentCueIndex        = nan(size(ChoiceExperimentStats.CHOICES));

  % Special case for infinite cue durations -- always on
  if isinf(vr.cueDuration)
    vr.currentCueTime(vr.trialType)     = vr.timeElapsed;
    vr.currentCueIndex(vr.trialType)    = 1;
    vr.cueAppeared{vr.trialType}(:)     = true;
    vr.cueOnset{vr.trialType}(:)        = 1;
    triangles                           = vr.tri_turnCue(vr.trialType,:);
    vr.defaultVisibility(triangles)     = true;
  end
  
end

%%_________________________________________________________________________
% --- Draw a random cue sequence
function [vr, nonTrivial] = drawCueSequence(vr)

  % Common storage
  vr.cuePos                 = cell(size(ChoiceExperimentStats.CHOICES));
  vr.cueOnset               = cell(size(ChoiceExperimentStats.CHOICES));
  vr.cueOffset              = cell(size(ChoiceExperimentStats.CHOICES));

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

  % Initialize times at which cues were turned on
  for iSide = 1:size(vr.cueCombo,1)
    vr.cueOnset{iSide}        = zeros(size(vr.cuePos{iSide}), vr.iterStr);
    vr.cueOffset{iSide}       = zeros(size(vr.cuePos{iSide}), vr.iterStr);
    vr.cueAppeared{iSide}     = false(size(vr.cuePos{iSide}));
  end

end

%%_________________________________________________________________________
% --- Trial and reward configuration
function vr = setupTrials(vr, shaping)

  % Sequence of progressively more difficult mazes; see docs for prepareMazes()
  if nargin < 2
    shaping             = vr.exper.userdata.trainee.protocol;
  end
  [mazes, criteria, globalSettings, vr]   ...
                        = shaping(vr);
  vr                    = prepareMazes(vr, mazes, criteria, globalSettings);

  % Number and mixing of trials
  vr.targetNumTrials    = eval(vr.exper.variables.targetNumTrials);
  vr.trialDuplication   = eval(vr.exper.variables.trialDuplication);
  vr.trialDispersion    = eval(vr.exper.variables.trialDispersion);
  vr.panSessionTrials   = eval(vr.exper.variables.panSessionTrials);

  % Nominal extents of world
  vr.worldXRange        = eval(vr.exper.variables.worldXRange);
  vr.worldYRange        = eval(vr.exper.variables.worldYRange);

  % Trial violation criteria
  vr.maxTrialDuration   = eval(vr.exper.variables.maxTrialDuration);
  [vr.iterFcn,vr.iterStr] = smallestUIntStorage(vr.maxTrialDuration / RigParameters.minIterationDT);

  % Special case with no animal -- only purpose is to return maze configuration
  hasTrainee            = isfield(vr.exper.userdata, 'trainee');


  %--------------------------------------------------------------------------

  % Sound for aversive stimulus
  vr.punishment         = loadSound('siren_6kHz_12kHz_1s.wav', 1.2, RigParameters.soundAdjustment);

  % Logged variables
  if hasTrainee
    vr.sensorMode       = vr.exper.userdata.trainee.virmenSensor;
    %vr.frictionCoeff    = vr.exper.userdata.trainee.virmenFrictionCoeff;
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
  cfg.blockData         = { 'mazeID', 'mainMazeID' };
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
  vr.exper.variables.cueVisibleAt = '0';                            % For PoissonStimulusTrain
  vr.experimentVars     = [ vr.stimulusParameters                   ...
                          , { 'cueDuration'                         ...
                            , 'lStart', 'lCue', 'lMemory', 'lArm'   ... for maze length
                            , 'maxExcessTravel'                     ...
                            } ];

  if ~hasTrainee
    return;
  end

  %--------------------------------------------------------------------------


  % Statistics for types of trials and success counts
  vr.protocol           = ChoiceExperimentStats(cfg.animal, cfg.label, cfg.totalTrials, numel(mazes));
  vr.protocol.plot(1 + ~RigParameters.hasDAQ);
  vr.protocol.addDrawMethod(TrainingRegiment.TRIAL_DRAWING);

  vr.protocol.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  vr.protocol.log('    %s : %s, session %d', vr.exper.userdata.trainee.name, datestr(now), vr.exper.userdata.trainee.sessionIndex);
  vr.protocol.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  vr.protocol.setDrawMethod(TrainingRegiment.(cfg.animal.trialDrawMethod{1}){cfg.animal.trialDrawMethod{2}});



  % Predetermine warmup and main mazes based on training history
  [vr.mainMazeID, vr.mazeID, vr.warmupIndex, vr.prevPerformance]  ...
                        = getTrainingLevel(vr.mazes, vr.exper.userdata.trainee, vr.protocol, vr.numMazesInProtocol, cfg.animal.autoAdvance);

  % Logging of experimental data
  vr.logger             = ExperimentLog(vr, cfg, vr.protocol, vr.iterFcn(inf));


  % Poisson stimulus trains, some identical across sessions
  vr.stimulusBank       = fullfile( parsePath(getfield(functions(shaping), 'file'))  ...
                                  , ['stimulus_trains_' func2str(shaping) '.mat']    ...
                                  );
  if exist(vr.stimulusBank, 'file')
    vr.protocol.log('Loading stimuli bank from %s.', vr.stimulusBank);
    bank                = load(vr.stimulusBank);
    vr.poissonStimuli   = bank.poissonStimuli;
    vr.poissonStimuli.setTrialMixing(vr.targetNumTrials, vr.trialDuplication, vr.trialDispersion);
  else
    choice              = questdlg( sprintf('Stimulus bank %s does not exist. Create?', vr.stimulusBank)  ...
                                  , 'Missing stimulus bank', 'Yes', 'No', 'Yes'                           ...
                                  );
    if strcmp(choice, 'No')
      vr.experimentEnded= true;
      return;
    end
    vr.poissonStimuli   = vr.stimulusGenerator(vr.targetNumTrials, vr.trialDuplication, vr.trialDispersion);
  end
  vr.protocol.log('Configured %d trials with duplication factor %.3g, mixed with %d pan-session trials from bank.', vr.targetNumTrials, vr.trialDuplication, vr.panSessionTrials);

end
