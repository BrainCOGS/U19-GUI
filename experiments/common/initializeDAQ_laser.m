function vr = initializeDAQ_laser(vr)

  % Reset DAQ in case it is still in use
  daqreset;

  % Digital input/output lines used for reward delivery etc.
  if RigParameters.hasDAQ
    nidaqPulse          ('end');
%     nidaqAIread         ('end');
    nidaqDOwrite2ports  ('end');
    nidaqDIread         ('end');

    nidaqPulse          ('init', RigParameters.nidaqDevice, RigParameters.nidaqPort, RigParameters.rewardChannel); % reward
%     nidaqAIread         ('init', RigParameters.nidaqDevice, RigParameters.aiChannels); % receive analog data sent to lasre/galvos (sync)
    nidaqDOwrite2ports  ('init', RigParameters.nidaqDevice, RigParameters.nidaqDOPort, ...
        RigParameters.locationChannels, RigParameters.virmenStateChannels); % send virmen info and galvo commands
    nidaqDIread         ('init', RigParameters.nidaqDevice, RigParameters.diPort, RigParameters.diChannels); % receive "OK to proceed" messages from laser PC
    
    if isprop(RigParameters,'airpuffChannel') 
        nidaqPulse2     ('end');
        nidaqPulse2     ('init', RigParameters.nidaqDevice, RigParameters.nidaqPort, RigParameters.airpuffChannel); % reward
    end
  end

   nidaqDOwrite2ports('writeDO',zeros(1,length([ RigParameters.locationChannels RigParameters.virmenStateChannels])));
  % TCP/IP
end
