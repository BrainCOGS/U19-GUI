function vr = checkSqual(vr)

% Check for open instruments, close and delete those found
instr = instrfindall;
n_instr=size(instr);
if n_instr>=1
  for m=1:n_instr
    fclose(instr(m));
    delete(instr(m));
  end
end

% Setup serial port
s = serial(RigParameters.arduinoPort);
s.BaudRate = 250000; %make sure arduino code uses same BaudRate
s.DataBits = 8;
s.StopBits = 1;
s.Parity = 'none';
s.Timeout = 1;
s.inputbuffersize=1000;
fopen(s);


squals = nan(100,1);
for n = 1:100 % average over 100 measurements
  fprintf(s,'q'); % Send command to return SQUAL
  iTry = 1;
  while s.BytesAvailable < 1 || iTry < 20
      iTry = iTry + 1;
  end
  try squals(n) = fread(s,s.BytesAvailable,'uint8'); end
end

vr.squal = nanmean(squals);

if isnan(vr.squal)
  vr.protocol.log ( 'Could not check squal, no bytes received' );
elseif vr.squal > 50
  vr.protocol.log ( 'Good SQUAL (motion sensor): %1.1f' , vr.squal);
elseif vr.squal > 30 && vr.squal < 50
  vr.protocol.log ( 'Mediocre SQUAL (motion sensor): %1.1f' , vr.squal);
else
  vr.protocol.log ( 'Bad SQUAL (motion sensor): %1.1f\nCHECK SENSOR!' , vr.squal );
end

fclose(s);
delete(s);
clear s;