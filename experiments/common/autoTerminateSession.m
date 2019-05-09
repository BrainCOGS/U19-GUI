%% automatic termination of session based on performance

function [vr,mazeChanged] = autoTerminateSession(vr)


%% remaining time and reward
mazeChanged       = false;
remainingTime     = vr.protocol.animal.session(vr.protocol.animal.sessionIndex).duration * 60;
if ~isempty(vr.protocol.startTime)
  remainingTime   = remainingTime - etime(clock, vr.protocol.startTime);
else
  vr.extraWaterMaze = false;
  return
end
hasEnoughWater    = vr.protocol.totalRewards >= vr.protocol.animal.waterAlloc;


%% if running visually guided maze just to get enough water
if ~isfield(vr,'extraWaterMaze_startTime'); vr.extraWaterMaze_startTime = nan; end
if ~isfield(vr,'extraWaterMaze'); vr.extraWaterMaze = false; end

% run warm-up maze until getting enough water or until 10 extra minutes
if vr.extraWaterMaze
  if etime(clock, vr.extraWaterMaze_startTime) > 10*60 || hasEnoughWater
    vr.experimentEnded  = true;
    vr                  = notifyUser_rigs(vr);
    if etime(clock, vr.extraWaterMaze_startTime) > 10*60
      vr.protocol.log ( 'Session terminated because time in maze %d exceeded 10 min' , vr.mazeID );
    end
    if hasEnoughWater
      vr.protocol.log ( 'Session terminated because mouse got enough reward' );
    end
  end
  return
end

%% if close to session end / got all reward
if    vr.protocol.numTrials    > 250       ...
    | remainingTime            < 0         ...
    | (remainingTime           < 10 & hasEnoughWater)
  
  % Performance needs to be decreasing on both fast and slower time scales
  % (sigma = 5, over 10 trials, sigma = 10, over 10 and 20 trials), each
  % with specific thresholds detrmined heuristically from data
  criteria         = vr.mazes(vr.mainMazeID).criteria;
  smoothNTrials    = [5 10]; % sigma of sliding Gaussian window for performance
  perfDecreaseTh5  = 0.03; % avg performance decrease per trial to trigger termination
  perfDecreaseTh10 = [0.018 0.012]; % avg performance decrease per trial to trigger termination
  perfTh           = criteria.blockPerform; % absolute performance threshold
  isCorrect        = sum(vr.protocol.isCorrect(:,1:vr.protocol.currentTrial));
  trialIdx         = max([1 numel(isCorrect)-50]):numel(isCorrect);
  isCorrect        = isCorrect(trialIdx); % use max last 50 trials for speed
  
  runningPerf5     = imgaussfilt(isCorrect, smoothNTrials(1)); % running perfroamce 
  runningPerf10    = imgaussfilt(isCorrect, smoothNTrials(2)); % running perfroamce 
  trialIdx10       = max([1 numel(runningPerf10)-10]):numel(runningPerf10); % only last smoothNTrials will be used to trigger termination
  trialIdx20       = max([1 numel(runningPerf10)-20]):numel(runningPerf10); % only last smoothNTrials will be used to trigger termination
  isDecreasing     =    mean(diff(runningPerf5(trialIdx10)))  <= -perfDecreaseTh5  ...
                     && mean(diff(runningPerf10(trialIdx10))) <= -perfDecreaseTh10(1) ...
                     && mean(diff(runningPerf10(trialIdx20))) <= -perfDecreaseTh10(2);
                   
  % if perfromance is dropping and all water has been received, stop
  if runningPerf10(end) <= perfTh && isDecreasing && hasEnoughWater
    vr.experimentEnded  = true;
    vr                  = notifyUser_rigs(vr);
    vr.protocol.log ( 'Session terminated because of drop in performance: %1.1f%% in last 10 trials (sigma=%d), %1.1f%% in last 10 trials (sigma=%d), and %1.1f%% in last 20 trials (sigma=%d) ', ...
                      mean(diff(runningPerf5(trialIdx10)))*100,  smoothNTrials(1), ...
                      mean(diff(runningPerf10(trialIdx10)))*100, smoothNTrials(2), ...
                      mean(diff(runningPerf10(trialIdx20)))*100, smoothNTrials(2)  ...
                      );
  
  % otherwise if performance is low and time is up, but there is water to be had, 
  % further increase reward and switch animal back to visually-guided maze
  % if main maze is past that
  elseif runningPerf10(end) <= perfTh && ~hasEnoughWater && remainingTime < 0
    
    if ~isempty(criteria.warmupMaze)
      vr.warmupIndex              = 1;
      vr.mazeID                   = criteria.warmupMaze(vr.warmupIndex);
      mazeChanged                 = true;
      vr.extraWaterMaze           = true;
      vr.extraWaterMaze_startTime = clock;
      
      vr.protocol.log ( 'Switching back to maze %d maze because of poor performance' , vr.mazeID )
    end

    % also adjust reward
    maxScale = 3;
    
    if vr.protocol.rewardScale < maxScale
      newScale = vr.protocol.rewardScale*2;
      newScale = round(newScale*10)/10; % 0.1 increements

      if newScale > maxScale
        newScale = maxScale;
      end
      
      vr.protocol.setRewardScale(newScale);
      vr.numRewardDrops = 2;
      
      vr.protocol.log ( 'Scaling rewards by %.3g ' ...
        , vr.protocol.rewardScale);
    end

  end

% otherwise stop if animal has been running for 2h or has gotten > 80% extra rewards   
elseif etime(clock, vr.protocol.startTime) > 60 * 120 | ...
       vr.protocol.totalRewards > vr.protocol.animal.waterAlloc*2
  
  vr.experimentEnded  = true;
  vr                  = notifyUser_rigs(vr);
  
  if etime(clock, vr.protocol.startTime) > 60 * 120
    vr.protocol.log ( 'Session terminated because of long duration' );
  end
  if vr.protocol.totalRewards > vr.protocol.animal.waterAlloc*2
    vr.protocol.log ( 'Session terminated because mouse received 100% over water allotment' );
  end
  
end