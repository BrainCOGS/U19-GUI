function terminateDAQ(vr)

  if RigParameters.hasDAQ
    nidaqPulse('end');
  end
  if RigParameters.hasSyncComm
    nidaqI2C('end');
  end
  
end
