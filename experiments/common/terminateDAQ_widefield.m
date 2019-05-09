function terminateDAQ_widefield(vr)

  if RigParameters.hasDAQ
    nidaqPulse   ('end');
    nidaqDIread  ('end');
    nidaqPulse2  ('end');
    nidaqPulse3  ('end');
  end
  if RigParameters.hasSyncComm
    nidaqI2C('end');
  end
  
end
