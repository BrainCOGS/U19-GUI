function vr = initializeDAQ_widefield(vr)

  % Reset DAQ in case it is still in use
  daqreset;

  % Digital input/output lines used for reward delivery etc.
  if RigParameters.hasDAQ
    nidaqPulse          ('end');
    nidaqPulse2         ('end');
    nidaqPulse3         ('end');
    nidaqDIread         ('end');

    nidaqPulse          ('init', RigParameters.nidaqDevice, RigParameters.nidaqPort, RigParameters.rewardChannel); % reward
    nidaqPulse2         ('init', RigParameters.nidaqDevice, RigParameters.nidaqPort, RigParameters.camTrigChannel); % camera start trigger
    nidaqPulse3         ('init', RigParameters.nidaqDevice, RigParameters.nidaqPort, RigParameters.shutterChannel); % shutter control
    nidaqDIread         ('init', RigParameters.nidaqDevice, RigParameters.nidaqPort, RigParameters.camInChannel); % receive analog data from cam (sync)
    
  end

end
