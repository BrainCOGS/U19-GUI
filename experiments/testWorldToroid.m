function code = testWorldToroid
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


vr.text(1).string = '0';
vr.text(1).position = [-.14 .1];
vr.text(1).size = .03;
vr.text(1).color = [1 1 1];



% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)


vr.text(1).string = sprintf('POSITION %0.2f %0.2f %0.2f',vr.position(1),vr.position(2),vr.position(4));






function vr = terminationCodeFun(vr)

% terminate DAQ
% terminateDAQ(vr)






