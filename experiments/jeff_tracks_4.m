function code = jeff_tracks_4
% jeff_tracks_4   Code for the ViRMEn experiment jeff_tracks_4.
%   code = jeff_tracks_4   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT



% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)

% ENSURE COMPATIBILITY WITH OTHER RIGS
vr.odor = 0;

vr.optimizeRendering = true;



% CONTEXTS AND SWITCHING

% set context switching scheme
switch 2
    case 1
        vr.contextSwitchingScheme.name = 'R@366_stable';
        vr.contextSwitchingScheme.contexts = {'long_366'};
        vr.contextSwitchingScheme.durations = Inf;
        
    case 2 % 366-166-366, 21 min cycle
        vr.contextSwitchingScheme.name = 'R@366_R@166_R@366';
        vr.contextSwitchingScheme.contexts = {'long_366','long_166','long_366'};
        timeA = 7+2*rand(1); timeB = 12+2*rand(1);  timeC = 21 - timeA - timeB;
        %timeA = 6+2*rand(1); timeB = 6+2*rand(1);  timeC = 21 - timeA - timeB;
        vr.contextSwitchingScheme.durations = [timeA timeB timeC];
        vr.currentPhase = 0;
        
    case 3 % long-short-long, 21 min cycle
        vr.contextSwitchingScheme.name = 'long_short_long';
        vr.contextSwitchingScheme.contexts = {'long_366','short_230','long_366'};
        %timeA = 7+2*rand(1); timeB = 12+2*rand(1);  timeC = 21 - timeA - timeB;
        timeA = 6+2*rand(1); timeB = 6+2*rand(1); timeC = 21 - timeA - timeB;
        vr.contextSwitchingScheme.durations = [timeA timeB timeC];
        vr.currentPhase = 0;
        
    case 4 % 4ml_8ml_4ml, 21 min cycle
        vr.contextSwitchingScheme.name = '4ml_8ml_4ml';
        vr.contextSwitchingScheme.contexts = {'long_366','long_166_big','long_366'};
        %timeA = 7+2*rand(1); timeB = 12+2*rand(1);  timeC = 21 - timeA - timeB;
        timeA = 4+2*rand(1); timeB = 6+2*rand(1); timeC = 14 - timeA - timeB;
        vr.contextSwitchingScheme.durations = [timeA timeB timeC];
        vr.currentPhase = 0;
        
    case 5 % 366-passive, 20 min cycle
        vr.contextSwitchingScheme.name = 'R@366_passive_R@366';
        vr.contextSwitchingScheme.contexts = {'long_366','long_366_passive','long_366'};
        timeA = 5+2*rand(1); timeB = 9+2*rand(1);  timeC = 20 - timeA - timeB;
        vr.contextSwitchingScheme.durations = [timeA timeB timeC];
        vr.currentPhase = 0;
        
    otherwise
        error('unrecognized context')
end


% switch to first context

% load first context
vr = switchToContext(vr,vr.contextSwitchingScheme.contexts{1});
% set conditions for switch
vr = setSwitchCondition(vr);






% INITIALIZE VARIABLES


% initialize counters
vr.traversalCount = 0;
vr.rewardCount = 0;


vr.allPositions = [];
vr.wheelData = {};


vr = initializeDAQ(vr);



% set up parameters of wheel and angular encoder
vr.wheelCircumference = pi*6;
vr.convertToCm = @(x) vr.wheelCircumference*(1-x/5);


% variables for passive replay
vr.passiveResumeTime = 0;
vr.lastUpdateTime = now;
vr.passivePauseReady = true;
vr.passiveViewing = false;


% TRIANGLE DRAWING

% longest distance (in front of mouse) at which to draw
vr.drawDistance = 200;

% replicate triangles in each track to make it appear infinte
if vr.optimizeRendering
  for whichWorld = 1:length(vr.worlds)
    vr = replicateEnvironmentWithOffset(vr,whichWorld,getTrackEnd(vr,whichWorld));
  end
end


% identify earliest point of each triangle

ve = vr.worlds{1}.surface.vertices;
tr = vr.worlds{1}.surface.triangulation;
% find smallest y value in each triangle
vr.minTriVal = min([ve(2,1+tr(1,:)); ...
    ve(2,1+tr(2,:)); ...
    ve(2,1+tr(3,:))],[],1);
  
  
if vr.optimizeRendering
  % make only close triangles visible initially
  vr.worlds{1}.surface.visible(vr.minTriVal > vr.drawDistance) = false;
end


%disp([sum(vr.worlds{1}.surface.visible) length(vr.worlds{1}.surface.visible)])



if vr.optimizeRendering
  
  % MAKE ENVIRONMENT BLUE
  
  % set red and green to 0
  for ww=1:length(vr.worlds)
    for cc=1:2
      vr.worlds{ww}.surface.colors(cc,:) = 0*vr.worlds{ww}.surface.colors(cc,:);
    end
    vr.worlds{ww}.surface.colors(3,:) = 1*vr.worlds{ww}.surface.colors(3,:);
  end
  
  
  
  % ENSURE BACKGROUND IS MIDDLE OF LIGHT LEVELS
  
  vr.worlds{1}.backgroundColor = [0 0 eval(vr.exper.variables.color_5)];
  vr.worlds{2}.backgroundColor = [0 0 eval(vr.exper.variables.color_5)];
  
end


% GRAPHICAL INFORMATION DISPLAY

% reward display text
vr.text(1).string = '# REWARDS';
vr.text(1).position = [.5 -0.5];
vr.text(1).size = .06;
vr.text(1).color = [1 0 0];
vr.text(2).string = '# R/MIN';
vr.text(2).position = [.5 -0.65];
vr.text(2).size = .06;
vr.text(2).color = [1 0 0];

% running speed
vr.text(3).string = '# CM/SEC';
vr.text(3).position = [.5 -0.8];
vr.text(3).size = .06;
vr.text(3).color = [1 0 0];


% world switch time text
vr.text(4).string = '0';
vr.text(4).position = [-1.3 -0.8];
vr.text(4).size = .06;
vr.text(4).color = [0 1 0];
vr.text(5).string = '0';
vr.text(5).position = [-1.3 -0.65];
vr.text(5).size = .06;
vr.text(5).color = [0 1 0];

% reward location
vr.text(6).string = '0';
vr.text(6).position = [-1.3 -0.5];
vr.text(6).size = .06;
vr.text(6).color = [0 1 0];

% display in info window
[vr.text(1:6).window] = deal(2);

% note start time
vr.startTime = now;



% set speed
vr.speeds = zeros(1,30);
vr.lastPosTime = [];



% INITIALIZE LOG

%vr = initializeLog(vr,'C:\Users\tankadmin.PNI-C42-OB2-VR2\Desktop\Jeff\Dropbox\virmenLogs');
vr.rewardSignal = 0; % used only to keep track in log




% WAIT TO ALLOW TIME TO SWITCH KEYBOARD

fprintf('context is %s\n',vr.contextSwitchingScheme.name)

%pause(5)


assignin('base','vr',vr)




vr.allTimes = [];

% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)

vr.allTimes(end+1) = now;




% TELEPORT, DECIDE WHETHER TO SWITCH CONTEXT


if vr.position(2) > vr.trackEnd % test if the animal is at the end of the track
    vr.position(2) = 0; % set the animal’s y position to 0
    vr.dp([1 3]) = 0; % prevent any additional movement during teleportation
    
    % set up reward
    vr.rewardReady = 1;
    vr.rewardIndex = 1;
    vr.nextRewardLocation = vr.rewardLocations(vr.rewardIndex);
    
    vr.traversalCount = vr.traversalCount + 1;
    
    % make distant triangles invisible
    vr.worlds{1}.surface.visible(vr.minTriVal > vr.drawDistance) = false;
    
    % if conditions met to switch context...
    if now > vr.contextSwitchTime || vr.traversalCount >= vr.contextSwitchTraversal
        % switch worlds
        vr = switchToContext(vr,vr.nextContext);
        % set conditions for next switch
        vr = setSwitchCondition(vr);
    end
    
    % for passive viewing
    vr.passivePauseReady = true;
end





% make near triangles visible
if vr.optimizeRendering
  vr.worlds{1}.surface.visible(vr.minTriVal < vr.position(2)+vr.drawDistance) = true;
end



% GIVE REWARD

if vr.rewardReady && vr.position(2) > vr.nextRewardLocation 
    % deliver the reward
    %deliverReward(vr, RigParameters.rewardDuration_4ml);
    deliverReward(vr, vr.rewardSize);
    
    % for log
    vr.rewardSignal = 1;
    
    % increment reward count
    vr.rewardCount = vr.rewardCount + 1;
    
    
    % if this was the last reward to deliver this traversal...
    if vr.rewardIndex == length(vr.rewardLocations)
        % set ready signal to 0
        vr.rewardReady = 0;
    else
        % otherwise, prep for next reward
        
        % get ready to deliver
        vr.rewardReady = 1;
        % increment rewardIndex
        vr.rewardIndex = mod(vr.rewardIndex,length(vr.rewardLocations)) + 1;
        % set location
        vr.nextRewardLocation = vr.rewardLocations(vr.rewardIndex);
    end
    
end


%if vr.rewardSignal, disp('rewarded!'), end



% ENSURE FACING FORWARD

if 1
    % restrict angle
    maxAngle = pi*0.49;
    if abs(vr.position(4)) > maxAngle
        vr.position(4) = sign(vr.position(4))*maxAngle;
    end
    % reverse angular motion
    %vr.dp(4) = -vr.dp(4);
    
    % enforce facing forward
    vr.dp(4)=0;
end

% prevent lateral movement
vr.dp(1)=0;






% UPDATE DAQ

% update position and context
%updateDAQ(vr)






% SET POSITION

if 0
        
        % get recent angular encoder values from daq (also lick signal?)
        vr = readDAQ(vr);
        
        % convert readings to cm
        wheelReadings = vr.convertToCm(vr.angularEncoderData);
        
        % fit vector of readings to estimate current position
        currentWheelPosition = estimateWheelPosition(wheelReadings,vr.wheelCircumference,'parabolic');
        
        % after the first iteration...
        if isfield(vr,'lastWheelPosition')
            
            % compute offset from the last iteration
            theOffset = currentWheelPosition - vr.lastWheelPosition;
            
            % wrap around large positive or negative offsets
            theOffset = mod(theOffset+vr.wheelCircumference/2,vr.wheelCircumference)-vr.wheelCircumference/2;
            
            if ~vr.passiveViewing
                % use wheel position
                    
                    % apply offset to update y position
                    vr.position(2) = vr.position(2) + theOffset;
                    
                    
            else
                % passive replay
                if now > vr.passiveResumeTime
                    
                    dt = (now-vr.lastUpdateTime)*24*3600;
                    passiveVelocity = 20;
                    vr.position(2) = vr.position(2) + dt * passiveVelocity;
                    
                    if vr.position(2) > 370 && vr.passivePauseReady
                        vr.passiveResumeTime = now + 10/24/3600;
                        vr.passivePauseReady = false;
                    end
                end
                
                vr.lastUpdateTime = now;
                
                
            end
            
            
            
        end
        
        % note current position for next time
        vr.lastWheelPosition = currentWheelPosition;
end        

% ensure velocity is 0
%vr.dp = [0 0 0 0];


% note for diagnostic purposes
%vr.allPositions = [vr.allPositions; vr.position(2)];
%vr.wheelData{length(vr.wheelData)+1} = vr.angularEncoderData';



% maxBackward = 5;
% 
% % convert to units of cm
% vals = -1*(vals)/5*vr.wheelCircumference;
% 
% vals = vals(end-10:end);
% 
% % ensure all are close to last one
% lastVal = vals(end);
% vals = mod(vals-lastVal+vr.wheelCircumference-maxBackward,vr.wheelCircumference)+maxBackward+lastVal;
% 
% % take mean
% currentPosition = mod(mean(vals),vr.wheelCircumference);
%
% % update (if previous measurement exists
% if isfield(vr,'lastWheelPosition')
%     
%     % note change in position
%     theOffset = currentPosition - vr.lastWheelPosition;
%     
%     % compute velocity (only used to decide when to wrap around)
%     vel = theOffset / ( (now - vr.lastUpdateTime) * 24 * 3600);
%     if vel < -10
%         disp(theOffset)
%         theOffset = theOffset + vr.wheelCircumference;
%     end
%    
%     % update position
%     vr.position(2) = vr.position(2) + theOffset;
% end
%
%vr.lastUpdateTime = now;
% % save this time for next iteration
%vr.lastWheelPosition = currentPosition;







% UPDATE LOG

% update log file
% measurementsToSave = [...
%     now...
%     vr.position([2])...
%     vr.dp([2])...
%     vr.rewardSignal ...
%     vr.lickSignal ...
%     vr.contextValue ...
%     vr.nextRewardLocation];
%updateLog(vr,measurementsToSave)





% GRAPHICAL DISPLAY

% reward rate
vr.text(1).string = sprintf('%5d REWARDS',vr.rewardCount);
vr.text(2).string = sprintf('%5.1f R/MIN',vr.rewardCount/(now-vr.startTime)/24/60);
vr.text(3).string = sprintf('%5.0f CM/SEC',mean(vr.speeds));

% update list of recent positions/times to compute speed
if ~isempty(vr.lastPosTime)
    vr.speeds = [vr.speeds(2:end) ...
        (vr.position(2)-vr.lastPosTime(1)) / (now - vr.lastPosTime(2)) /24/3600];
end
vr.lastPosTime = [vr.position(2) now];


% update world switch timer
switchDelay = (vr.contextSwitchTime-now)*24*60;
if switchDelay < 0
    vr.text(4).string = upper(sprintf('%0.0f TO SWITCH',switchDelay*60));
elseif  switchDelay == inf
    vr.text(4).string = 'INF TO SWITCH';
else
    vr.text(4).string = upper(sprintf('%d.%02.0f TO SWITCH',...
        floor(switchDelay),mod(switchDelay*60,60)));
end
vr.text(5).string = upper(sprintf('%d R TO SWITCH',vr.contextSwitchTraversal-vr.traversalCount));
vr.text(6).string = sprintf('R AT %d',vr.nextRewardLocation);






% LISTEN FOR KEYSTROKES
if ~isnan(vr.keyPressed)
    switch vr.keyPressed
        case {'s','S'}; % switch now
            vr.contextSwitchTime = now;
            vr.contextSwitchTraversal = vr.traversalCount;
        case {'m','M'}; % add a minute to switch time
            vr.contextSwitchTime = vr.contextSwitchTime + 1/24/60;
        case {'f','F'}; % add five minutes to switch time
            vr.contextSwitchTime = vr.contextSwitchTime + 5/24/60;
        case {'i','I'}; % set switch time to infinity
            vr.contextSwitchTime = inf;
        case {'t','T'}; % add one to reward count
            vr.contextSwitchTraversal = vr.contextSwitchTraversal + 1;
    end
end


% for log
vr.rewardSignal = 0;



% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)


assignin('base','calibTimes',24*3600*vr.allTimes);


% close log
%terminateLog(vr)
%assignin('base','lastLogPath',vr.logPath)

% reset daq values
%putsample(vr.ao,[0 0]);
%daqreset

%figure;plot(vr.allPositions,'.-')
%assignin('base','wheelData',vr.wheelData)



% --- SWITCH TO SPECIFIED CONTEXT
function vr = switchToContext(vr,whichContext)

% set the current world and the reward locations

% defaults
vr.rewardSize = RigParameters.rewardDuration;
vr.passiveViewing = false;

switch whichContext
    case 'long_366' % long, R@366
        vr.currentWorld = 1;
        vr.rewardLocations = 366;
        vr.contextValue = 1;
        
    case 'long_166' % long, R@166
        vr.currentWorld = 1;
        vr.rewardLocations = 166;
        vr.contextValue = 2;
        
    case 'short_230' % short, R@230
        vr.currentWorld = 2;
        vr.rewardLocations = 230;
        vr.contextValue = 3;
        
    case 'long_166_366' % long, R@166,366
        vr.currentWorld = 1;
        vr.rewardLocations = [166 366];
        vr.contextValue = 4;
        
    case 'long_166_big' % long, R@166, big reward
        vr.currentWorld = 1;
        vr.rewardLocations = 166;
        vr.contextValue = 5;
        vr.rewardSize = RigParameters.rewardDuration_8ml;
        
    case 'short_230_big' % short, R@230, big reward
        vr.currentWorld = 2;
        vr.rewardLocations = 230;
        vr.contextValue = 6;
        vr.rewardSize = RigParameters.rewardDuration_8ml;
        
    case 'long_366_passive' % long, R@366, passive
        vr.currentWorld = 1;
        vr.rewardLocations = 366;
        vr.contextValue = 7;
        vr.passiveViewing = true;
        vr.lastUpdateTime = now;
            
    otherwise
        disp(whichContext)
        error('new context not recognized')
end

% get location where track ends
vr.trackEnd = getTrackEnd(vr,vr.currentWorld);

% set up reward delivery variables
vr.rewardLocations = sort(vr.rewardLocations);
vr.rewardReady = 1;
vr.rewardIndex = 1;
vr.nextRewardLocation = vr.rewardLocations(vr.rewardIndex);


% get vertex from the trackEndWall
%trackEndIndex = vr.worlds{vr.currentWorld}.objects.indices.trackEndWall;
%trackEndVertex = vr.worlds{vr.currentWorld}.objects.vertices(trackEndIndex,1);
% note its y position
%vr.trackEnd = vr.worlds{vr.currentWorld}.surface.vertices(2, vr.trackEndVertex);




% --- SET CONDITION FOR NEXT SWITCH
function vr = setSwitchCondition(vr)
% based on the current context switching scheme and context, establish
% criteria for when to switch to the next context


% default to neither traversals nor time causing switch
vr.contextSwitchTraversal = Inf;
vr.contextSwitchTime = Inf;

% add condition so that one of them causes switch
switch vr.contextSwitchingScheme.name
    
    case 'R@366_stable'
        % don't ever change
        vr.currentPhase = 1;
        vr.nextPhase = 1;
        vr.nextContext = vr.contextSwitchingScheme.contexts{1};
        
    case {'R@366_R@166_R@366', 'long_short_long', '4ml_8ml_4ml','R@366_passive_R@366'}
        % increment current phase and next planned phase
        vr.currentPhase = mod(vr.currentPhase,3) + 1;
        vr.nextPhase = mod(vr.currentPhase,3) + 1;
        % set switch time
        vr.contextSwitchTime = now + vr.contextSwitchingScheme.durations(vr.currentPhase)/24/60;
        % set next context
        vr.nextContext = vr.contextSwitchingScheme.contexts{vr.nextPhase};
 
        
    case 1 %
        vr.contextSwitchTime = now + 7/24/60;
    case 2 %
        vr.contextSwitchTraversal = vr.contextSwitchTraversal + 10 + floor(rand*3);
        
    otherwise
        error('context switching scheme %s not recognized',vr.contextSwitchingScheme.name)
end


% reset traversal counter
vr.traversalCount = 0;





% --- GET ENDPOINT OF TRACK
function trackEnd = getTrackEnd(vr,whichWorld)
% get y position of trackEndWall
trackEnd = 400;return
% get vertex from the trackEndWall
trackEndIndex = vr.worlds{whichWorld}.objects.indices.trackEndWall;
trackEndVertex = vr.worlds{whichWorld}.objects.vertices(trackEndIndex,1);
% note its y position
trackEnd = vr.worlds{whichWorld}.surface.vertices(2, trackEndVertex);

