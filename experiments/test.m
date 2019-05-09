function code = test
% test   Code for the ViRMEn experiment test.
%   code = test   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT



% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)

% Define a textbox and set its position, size and color
vr.text(1).position = [-0.8 0.5]; % upper-left corner of the screen
vr.text(1).size = 0.03; % letter size as fraction of the screen
vr.text(1).color = [1 1 0]; % yellow
vr.startTime = now;

vr = initializeVRRig(vr);
vr = adjustColorsForProjector(vr);


% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)

% On every iteration, update the string to display the time elapsed
vr.text(1).string = ['TIME ' datestr(now-vr.startTime,'MM.SS')];

if vr.textClicked == 1 % check if textbox #1 has been clicked
  beep;
  pause(0.1);
end


% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)
