function code = twoEnvironmentsSwitching
% twoEnvironmentsSwitching   Code for the ViRMEn experiment twoEnvironmentsSwitching.
%   code = twoEnvironmentsSwitching   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT



% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)


vr.minDistance = eval(vr.exper.variables.minDistance);
vr.minStartDistance = eval(vr.exper.variables.minStartDistance);
vr.maxStartDistance = eval(vr.exper.variables.maxStartDistance);
vr.randomRadiusExponent = eval(vr.exper.variables.randomRadiusExponent);
vr.floorWidth = eval(vr.exper.variables.floorWidth);
vr.startingOrientation = eval(vr.exper.variables.startingOrientation);
vr.turnSpeed = eval(vr.exper.variables.turnSpeed);
vr.rewardProbability = eval(vr.exper.variables.rewardProbability);
vr.freeRewards = eval(vr.exper.variables.freeRewards);
vr.debugMode = eval(vr.exper.variables.debugMode);

vr.currentWorld = eval(vr.exper.variables.startWorld);

if ~vr.debugMode
%     [vr.rewardSound vr.rewardFs] = wavread('ding.wav');

    % Start the DAQ acquisition
    daqreset; %reset DAQ in case it's still in use by a previous Matlab program
    vr.ai = analoginput('nidaq','dev1'); % connect to the DAQ card
    addchannel(vr.ai,0:1); % start channels 0 and 1
    set(vr.ai,'samplerate',1000,'samplespertrigger',inf);
    set(vr.ai,'bufferingconfig',[8 100]);
    set(vr.ai,'loggingmode','Disk');
    vr.tempfile = [tempname '.log'];
    set(vr.ai,'logfilename',vr.tempfile);
    set(vr.ai,'DataMissedFcn',@datamissed);
    start(vr.ai); % start acquisition
    
    vr.ao = analogoutput('nidaq','dev1');
    addchannel(vr.ao,0);
    set(vr.ao,'samplerate',10000);
    
    vr.finalPathname = 'C:\Users\tankadmin\Dropbox\virmenLogs';
    vr.pathname = 'C:\Users\tankadmin\Desktop\testlogs';
    vr.filename = datestr(now,'yyyymmddTHHMMSS');
    exper = vr.exper; %#ok<NASGU>
    save([vr.pathname '\' vr.filename '.mat'],'exper');
    vr.fid = fopen([vr.pathname '\' vr.filename '.dat'],'w');
    vr.isStarting = true;
    
    vr.dio = digitalio('nidaq','dev1');
    addline(vr.dio,0:7,'out');
    start(vr.dio);
end

% % Set up text boxes
vr.text(1).string = '0';
vr.text(1).position = [-.14 .1];
vr.text(1).size = .03;
vr.text(1).color = [1 0 1];

vr.text(2).string = '0';
vr.text(2).position = [-.14 0];
vr.text(2).size = .03;
vr.text(2).color = [1 1 0];

% Store cylinder triangulation coordinates
for w = 1:length(vr.worlds)
    lst = vr.worlds{w}.objects.vertices(vr.worlds{w}.objects.indices.targetObject,:);
    vr.cylinderTriangulation{w} = vr.worlds{w}.surface.vertices(1:2,lst(1):lst(2));
end

% Store circular arena index
vr.circleIndex = vr.exper.indices.circularArena;

% Target initial position
ang = rand*2*pi;
r = vr.floorWidth/4;
vr.targetPosition = [r*cos(ang) r*sin(ang)];

% Initialize runtime variables
vr.numRewards = 0;
vr.numDeliver = 0;
vr.startTime = now;
vr.scaling = [13 13];
vr.frontAngle = NaN;
vr.backAngle = NaN;
vr.rememberMiss = false;

% Initialize position
r = vr.floorWidth/4;
th = rand*2*pi;
vr.position(1:2) = [r*cos(th) r*sin(th)];

% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)

% Update plots
vr.plotSize = 0.15;
drawnow
if vr.currentWorld == vr.circleIndex
    th = linspace(0,2*pi,200);
    vr.plot(1).x = sqrt(2)*[cos(th) nan cos(th)/2];
    vr.plot(1).y = sqrt(2)*[sin(th) nan sin(th)/2];
else
    vr.plot(1).x = [-1 1 1 -1 -1 NaN -1/2 1/2 1/2 -1/2 -1/2];
    vr.plot(1).y = [-1 -1 1 1 -1 NaN -1/2 -1/2 1/2 1/2 -1/2];
end
scr = get(0,'screensize');
aspectRatio = scr(3)/scr(4)*.8;
vr.plotX = (aspectRatio+1)/2;
vr.plotY = 0.75;
vr.plot(1).x = vr.plot(1).x*vr.plotSize+vr.plotX;
vr.plot(1).y = vr.plot(1).y*vr.plotSize+vr.plotY;
vr.plot(1).color = [1 1 0];
vr.plot(2).x = [-1 1 1 -1 -1]/100 + vr.plotSize*vr.position(1)/(vr.floorWidth/2) + vr.plotX;
vr.plot(2).y = [-1 -1 1 1 -1]/100 + vr.plotSize*vr.position(2)/(vr.floorWidth/2) + vr.plotY;
vr.plot(2).color = [1 0 0];
vr.plot(3).x = [-1 1 1 -1 -1]/100 + vr.plotSize*vr.targetPosition(1)/(vr.floorWidth/2) + vr.plotX;
vr.plot(3).y = [-1 -1 1 1 -1]/100 + vr.plotSize*vr.targetPosition(2)/(vr.floorWidth/2) + vr.plotY;
vr.plot(3).color = [0 1 0];

% Update time text box
vr.text(2).string = ['TIME ' datestr(now-vr.startTime,'MM.SS')];

% Turn the world gradually
if ~isnan(vr.turnSpeed)
    vr.position(4) = 2*pi*(now-vr.startTime)*24*vr.turnSpeed + vr.startingOrientation;
end

% Test if the target was hit
isReward = false;
isDeliver = false;
if norm(vr.targetPosition - vr.position(1:2)) < vr.minDistance
    isReward = true;
    isDeliver = (rand < vr.rewardProbability) || (vr.numRewards < vr.freeRewards);
end


% Update reward text box
if isReward
    vr.numRewards = vr.numRewards + 1;
    if isDeliver
        vr.numDeliver = vr.numDeliver + 1;
    end
    vr.text(1).string = ['R=' num2str(vr.numDeliver) '/' num2str(vr.numRewards)];
end


% Find a new position for the cylinder if the target was hit or missed
if isReward
    vr.targetPosition = vr.position(1:2);
    while norm(vr.targetPosition - vr.position(1:2)) <= vr.minStartDistance
        p = vr.randomRadiusExponent;
        vr.targetPosition = [inf inf];
        while norm(vr.targetPosition-vr.position(1:2)) >= vr.maxStartDistance
            if vr.currentWorld == vr.circleIndex
                theta = 2*pi*rand;
                R = (rand.^p)*sqrt(2)*vr.floorWidth/2;
                vr.targetPosition = [R*cos(theta) R*sin(theta)];
            else
                vr.targetPosition = (rand(1,2).^p)*vr.floorWidth/2 .* sign(rand(1,2)-0.5);
            end
        end
    end
end

% Relocate cylinder
if isReward || vr.iterations == 1
    for w = 1:length(vr.worlds)
        lst = vr.worlds{w}.objects.vertices(vr.worlds{w}.objects.indices.targetObject,:);
        vr.worlds{w}.surface.vertices(1,lst(1):lst(2)) = vr.cylinderTriangulation{w}(1,:)+vr.targetPosition(1);
        vr.worlds{w}.surface.vertices(2,lst(1):lst(2)) = vr.cylinderTriangulation{w}(2,:)+vr.targetPosition(2);
    end
end

% Beep in case the target was hit
if ~vr.debugMode
    if isReward
%         sound(vr.rewardSound,vr.rewardFs);
    end
end

% Write data to file
if ~vr.debugMode
    if (isReward && isDeliver) || vr.textClicked == 1
        putdata(vr.ao,[0 5 5 5 5 0]');
        start(vr.ao);
        stop(vr.ao);
    end
       
    measurementsToSave = [now vr.position([1:2,4]) vr.velocity(1:2) vr.currentWorld vr.targetPosition(1:2) isDeliver isReward];
    if vr.isStarting
        vr.isStarting = false;
        fwrite(vr.fid,length(measurementsToSave),'double');
    end
    fwrite(vr.fid,measurementsToSave,'double');
end

% Switch worlds if the text box was pressed
if vr.textClicked == 2
    vr.currentWorld = 3-vr.currentWorld;
end

% Send out synchronization pulse
switch mod(vr.iterations,5)
    case {0,1,3}
        v = mod(fix(vr.iterations),128);
    case 2
        v = mod(fix(vr.iterations/128),64)+128;
    case 4
        v = mod(fix(vr.iterations/8192),64)+192;
end

if ~vr.debugMode
	putvalue(vr.dio,v);
end
    
% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)

data = virmenGetFrame(1);
assignin('base','data',data);

if ~vr.debugMode
    fclose all;
    fid = fopen([vr.pathname '\' vr.filename '.dat']);
    data = fread(fid,'double');
    num = data(1);
    data = data(2:end);
    data = reshape(data,num,numel(data)/num);
    assignin('base','data',data);
    fclose all;
    stop(vr.ai);
    stop(vr.dio);
    delete(vr.tempfile);
    
    vr.window.Dispose;
    answer = inputdlg({'Rat number','Comment'},'Question',[1; 5]);
    if ~isempty(answer)
        comment = answer{2}; %#ok<NASGU>
        save([vr.pathname '\' vr.filename '.mat'],'comment','-append')
        if ~exist([vr.pathname '\' answer{1}],'dir')
            mkdir([vr.pathname '\' answer{1}]);
        end
        movefile([vr.pathname '\' vr.filename '.mat'],[vr.finalPathname '\' answer{1} '\' vr.filename '.mat']);
        movefile([vr.pathname '\' vr.filename '.dat'],[vr.finalPathname '\' answer{1} '\' vr.filename '.dat']);
    end
    
    disp([answer{1} ' - ' num2str(sum(data(end,:)))])
end