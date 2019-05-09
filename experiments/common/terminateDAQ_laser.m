function terminateDAQ_laser(vr)

  if RigParameters.hasDAQ
    nidaqPulse   ('end');
    nidaqAIread  ('end');
    nidaqDOwrite ('end');
    nidaqDIread  ('end');
  end
  if RigParameters.hasSyncComm
    nidaqI2C('end');
  end
  
end
