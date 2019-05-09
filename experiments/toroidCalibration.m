function code = toroidCalibration
% testWorldToroid   Code for the ViRMEn experiment testWorldToroid.
%   code = testWorldToroid   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT



% --- INITIALIZATION code: executes before the ViRMEN engine starts.
function vr = initializationCodeFun(vr)

% initialize DAQ inputs and outputs
% vr = initializeDAQ(vr);
%vr = initializeArduinoMouse(vr, 1, 1);

% vr.text(1).string = '0';
% vr.text(1).position = [-.14 .1];
% vr.text(1).size = .03;
% vr.text(1).color = [1 1 1];
% 
% vr.text(2).string = '0';
% vr.text(2).position = [-.14 0];
% vr.text(2).size = .03;
% vr.text(2).color = [1 1 1];
% 
% vr.text(3).string = 'HORIZON LINE';
% vr.text(3).position = [-0.16 0.4286 + 0.005];
% vr.text(3).size = .03;
% vr.text(3).color = [1 .5 .5];

%addlistener(vr.oglControl,'KeyDown',@oglKeyDown);

% plot concentric circles
aa=0:0.01:2*pi;
radii = [0.1:0.05:0.8 0.5];
for rr=1:length(radii)
    vr.plot(rr).x = radii(rr)*cos(aa);
    vr.plot(rr).y = radii(rr)*sin(aa);
    vr.plot(rr).color = [1 1 0];
end
vr.plot(end).color = [1 .5 .5];
% plot radial lines
vr.plot(length(radii)+1).x = [0 0 0 -1 1 0 -1 1 0 1 -1];
vr.plot(length(radii)+1).y = [-1 1 0 -1 1 0 1 -1 0 0 0];
vr.plot(length(radii)+1).color = [1 1 1];
% indicate horizon line


% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)


% vr.text(1).string = sprintf('POSITION %0.2f %0.2f %0.2f',vr.position(1),vr.position(2),vr.position(4));
% vr.text(2).string = sprintf('VELOCITY %0.2f %0.2f %0.2f',vr.velocity(1),vr.velocity(2),vr.velocity(4));




% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)

% terminate DAQ
% terminateDAQ(vr)

% close Arduino
if isfield(vr, 'mr')
  delete(vr.mr);
end
