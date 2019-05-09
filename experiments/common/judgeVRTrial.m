function vr = judgeVRTrial(vr, alwaysSuccess, freezeMovement)

  if nargin < 2
    alwaysSuccess   = false;
  end
  if nargin < 3
    freezeMovement  = true;
  end


  % Freeze movement for a set amount of time
  if freezeMovement
    vr              = freezeArduino(vr);
  end

  % If the correct choice has been made, enter reward state
  if vr.choice == vr.trialType || alwaysSuccess
    vr.state        = BehavioralState.DuringReward;
    vr.rewardFactor = vr.protocol.rewardScale;

  % Otherwise deliver aversive stimulus and a longer time-out period
  else
    if isfield(vr, 'punishment')
      play(vr.punishment.player);
      
%       if isprop(RigParameters,'airpuffChannel') 
%         nidaqPulse2('ttl', RigParameters.airpuffDuration*1000); % airpuff
%       end
    end

    vr.state        = BehavioralState.EndOfTrial;
    vr.rewardFactor = 0;
    vr.waitTime     = vr.trialEndPauseDur;
  end

end
