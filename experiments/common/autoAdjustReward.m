%% decides whether to increase reward if performance is dropping or predicted
% volume after 1h is less than 1

function vr = autoAdjustReward(vr)

%% do this only once in a session
if isfield(vr,'rewardAutoUpdated')
  if vr.rewardAutoUpdated; return; end
end

maxScale = 3;

%% remaining time
remainingTime     = vr.protocol.animal.session(vr.protocol.animal.sessionIndex).duration * 60;
if ~isempty(vr.protocol.startTime)
  remainingTime   = remainingTime - etime(clock, vr.protocol.startTime);
end

%% if past half-session (ish)
if vr.protocol.numTrials > 100 | remainingTime < 30 * 60
  
  performance = vr.protocol.getStatistics();
  criteria    = vr.mazes(vr.mainMazeID).criteria;

  if performance >= criteria.blockPerform + .05 % if performance is good, just adjust volume based on time
    
    trialDuration      = vr.protocol.getMeanTrialLength()                    ...
                                +      performance  * vr.itiCorrectDur       ...
                                + (1 - performance) * vr.itiWrongDur         ...
                                ;
    remainingTrials    = remainingTime / trialDuration;
    remainingAlloc     = vr.protocol.animal.waterAlloc - vr.protocol.totalRewards;
    
    newScale           = ( remainingAlloc     / RigParameters.rewardSize ) ...
                         / ( performance * remainingTrials          ) ;
    newScale           = round(newScale*10)/10; % 0.1 increements
    
    if newScale <= vr.protocol.rewardScale || ~isfinite(newScale)
      return
    elseif newScale > maxScale
      newScale = maxScale;
    end
    
    vr.protocol.setRewardScale(newScale);
    
    vr.protocol.log ( 'Scaling rewards by %.3g assuming %.3g%% correct %.3g trials (%.3gs/trial) in %.3gmin to achieve %.3gmL rewards' ...
      , vr.protocol.rewardScale               ...
      , performance * 100                     ...
      , remainingTrials, trialDuration        ...
      , remainingTime / 60, remainingAlloc    ...
      );
    
    vr.rewardAutoUpdated = true;
    
  else % otherwise increase by 50%
    
    newScale = vr.protocol.rewardScale*1.5;
    newScale = round(newScale*10)/10; % 0.1 increements
    
    if newScale < vr.protocol.rewardScale || ~isfinite(newScale)
      return
    elseif newScale > maxScale
      newScale = maxScale;
    end
    
    vr.protocol.setRewardScale(newScale);
    
    vr.protocol.log ( 'Scaling rewards by %.3g because of poor performance' ...
      , vr.protocol.rewardScale                                             ...
      );
    
    vr.rewardAutoUpdated = true;

  end
  
end

if vr.protocol.rewardScale >= 1.8
  vr.numRewardDrops = 2;
end

end