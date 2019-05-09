function vr = rewardVRTrial(vr, rewardFactor, doEndTrial)

  % Compute reward duration
  if nargin > 1
    rewardMSec  = rewardFactor * vr.rewardMSec;
  else
    rewardMSec  = vr.rewardMSec;
  end

  if RigParameters.hasDAQ
    if isfield(vr,'numRewardDrops')
      for iDrop = 1:vr.numRewardDrops
        deliverReward(vr, rewardMSec/vr.numRewardDrops); pause(0.33);
      end
    else
      deliverReward(vr, rewardMSec);
    end
  end

  % Reward duration needs to be converted to seconds
  if nargin < 3 || doEndTrial
    vr.waitTime = vr.trialEndPauseDur - rewardMSec/1000;
    vr.state    = BehavioralState.EndOfTrial;
  end
  
end
