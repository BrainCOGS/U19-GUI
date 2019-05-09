function code = empty
% empty   Code for the ViRMEn experiment empty.
%   code = empty   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT


% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)
vr.frameTime = [];
vr.arduinoTime = [];
vr.serialTimeLag = [];
vr.numArduinoReplies = [];
vr.pollIndex = [];
vr.xDots1 = [];
vr.yDots1 = [];
vr.xDots2 = [];
vr.yDots2 = [];
vr.dx = [];
vr.dy = [];
vr.timing_index = 0;

% initialize mouse communications via Arduino 
vr.hasArduino = true;
% vr = initializeArduinoReader(vr,1,1,MovementSensor.BottomVelocity);

vr = adjustColorsForProjector(vr);


% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)
vr.frameTime(end+1) = vr.dt*1000;
% vr.xDots2(end+1) = vr.sensorData(3);
% vr.yDots2(end+1) = vr.sensorData(4);
% vr.arduinoTime(end+1) = vr.sensorData(5);
% vr.numArduinoReplies(end+1) = vr.sensorDots(4);
% vr.pollIndex(end+1)         = vr.sensorDots(5);
vr.dx(end+1) = vr.dp(1);
vr.dy(end+1) = vr.dp(2);

% if vr.mr.toc_index == vr.timing_index
%   vr.serialTimeLag(end+1) = nan;
%   vr.serialCountLag(end+1) = nan;
% else
%   vr.serialTimeLag(end+1) = vr.mr.last_response_toc*1000;
%   vr.serialCountLag(end+1) = vr.mr.last_response_numpolls;
%   vr.timing_index = vr.mr.toc_index;
% end

% startTic = tic;
% try
%   [ vr.xDots1(end+1), vr.yDots1(end+1)                  ...
%   , vr.xDots2(end+1), vr.yDots2(end+1)                  ...
%   , vr.arduinoTime(end+1), vr.numArduinoReplies(end+1)  ...
%   , vr.pollIndex(end+1)                                 ...
%   ]                                                     ...
%         = arduinoReader('get');
%   vr.serialTimeLag(end+1) = toc(startTic);
% catch err
%   vr.xDots1(end+1)	= nan;
%   vr.yDots1(end+1)  = nan;
%   vr.xDots2(end+1)	= nan;
%   vr.yDots2(end+1)      = nan;
%   vr.arduinoTime(end+1)       = nan;
%   vr.numArduinoReplies(end+1) = nan;
%   vr.pollIndex(end+1)         = nan;
%   vr.serialTimeLag(end+1) = nan;
%   displayException(err);
% end
% arduinoReader('poll', vr.iterations);
% 

% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)
% save('C:\Data\timing_data.mat', 'vr');

% figure; histogram(vr.frameTime,0:.5:40); xlabel('Frame dt (ms)');
% figure; plot(vr.frameTime); xlabel('Frame'); ylabel('Frame dt (ms)');
% fprintf('\nmean: %1.2f\nmedian: %1.2f\nmax: %1.2f\nmin = %1.2f\n',mean(vr.frameTime),median(vr.frameTime),max(vr.frameTime),min(vr.frameTime))
% 
% figure; histogram(vr.serialTimeLag(isfinite(vr.serialTimeLag)), 0:.5:40); xlabel('poll\_mouse() response lag (ms)');
% figure; plot(vr.serialTimeLag); xlabel('Frame'); ylabel('poll\_mouse() response lag (ms)');
% 
% figure; histogram(vr.serialCountLag(isfinite(vr.serialCountLag)), -0.5:1:2.5, 'Normalization', 'probability'); xlabel('Number of polls between responses');
% figure; plot(vr.serialCountLag); xlabel('Frame'); ylabel('Number of polls between responses');

% delete(vr.mr);
% arduinoReader('end');
