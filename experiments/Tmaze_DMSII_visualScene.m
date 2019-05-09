function code = Tmaze_DMSII_visualScene

% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT



% --- INITIALIZATION code: executes before the ViRMEN engine starts.
function vr = initializationCodeFun(vr)

vr.debugMode = eval(vr.exper.variables.debugMode);
vr.hideWall = eval(vr.exper.variables.hideWall);
vr.noRewardWaiting = eval(vr.exper.variables.noRewardWaiting);

%% experimental parameters
vr.sampleCueLine1=eval(vr.exper.variables.stem_length1);
vr.sampleCueLine2=eval(vr.exper.variables.stem_length1)+eval(vr.exper.variables.l2);
vr.inSampleCueArea=false;

vr.testCueLine=eval(vr.exper.variables.stem_length1)+eval(vr.exper.variables.l2)+eval(vr.exper.variables.l3)-30;
vr.inTestCueArea=false;

vr.nearRewardLine=eval(vr.exper.variables.l_s2)*sin(pi/3)*0.8;
vr.inNearRewardArea=false;
vr.rewardLocation_x=eval(vr.exper.variables.l_s2)*sin(pi/3);
vr.rewardLocation_y=eval(vr.exper.variables.l_s2)*cos(pi/3)+vr.testCueLine+30;
vr.rewardWaitingTime=2;

vr.rewardLine=eval(vr.exper.variables.l_s2)*sin(pi/3);
vr.inRewardArea=false;

vr.rewardDelivered=false;
vr.rewardDur=0.1;

vr.trialEndPauseOver=false;
vr.inTrialEndPause=false;
vr.trialEndPauseDur=1.5;

vr.inITI=false;



%% stimulus

%cue pool in use [sample left right]
% normal
vr.cuePool=[1 1 2;2 1 2;1 2 1;2 2 1];

% % more left trials
% vr.cuePool=[1 1 2;2 1 2;1 2 1;2 2 1;1 1 2;2 2 1];

% % more right trials
% vr.cuePool=[1 1 2;2 1 2;1 2 1;2 2 1;1 2 1;2 1 2];

% % all left trials
% vr.cuePool=[1 1 2;2 2 1];

% % all right trials
% vr.cuePool=[1 2 1;2 1 2];

% vr.cuePool=[2 1 2];

% vr.cuePool=[1 1 2;2 1 2];

% vr.cuePool=[1 1 2;2 1 2;1 1 2;2 1 2;1 2 1;2 2 1];

% vr.cuePool=[1 1 2;2 1 2;1 2 1;2 2 1;2 1 2];

% vr.cuePool=[2 1 2];

for i=1:length(vr.worlds)
    % determine the index of sampleCueWall
    indx = vr.worlds{i}.objects.indices.sampleCueWall;
    lst = vr.worlds{i}.objects.triangles(indx,:);
    vr.sampleCueWallTriangles{i} = lst(1):lst(2);
    
    % determine the index of testWall_left
    indx = vr.worlds{i}.objects.indices.testWall_left;
    lst = vr.worlds{i}.objects.triangles(indx,:);
    vr.testWall_leftTriangles{i} = lst(1):lst(2);
    
    % determine the index of testWall_right
    indx = vr.worlds{i}.objects.indices.testWall_right;
    lst = vr.worlds{i}.objects.triangles(indx,:);
    vr.testWall_rightTriangles{i} = lst(1):lst(2);
end

% turn off red, decrease green and blue
for i=1:length(vr.worlds)
    vr.worlds{i}.surface.colors(1,:)=0.0*vr.worlds{i}.surface.colors(1,:);
    vr.worlds{i}.surface.colors(2,:)=0.2*vr.worlds{i}.surface.colors(2,:);
    vr.worlds{i}.surface.colors(3,:)=0.2*vr.worlds{i}.surface.colors(3,:);
end

vr.cue=0;

beep on;



%% communication with external programs

% initialize UDP for VR result display
vr = initializeUDPforVR(vr);

% initialize mouse communications via Arduino
if ~vr.debugMode
    vr = initializeArduino_1sensor(vr, 1, 1/5);
end


%% trial sequence

% random trial sequence: 1-left trial; 2-right trial
vr=generatePseudorandomTrialsforDMSII(vr, 500);

vr.trialNUM=1;
vr.currentWorld=vr.worldSequence(1);

if vr.hideWall
    vr.worlds{vr.currentWorld}.surface.visible(vr.sampleCueWallTriangles{vr.currentWorld})=false;
    vr.worlds{vr.currentWorld}.surface.visible(vr.testWall_leftTriangles{vr.currentWorld})=false;
    vr.worlds{vr.currentWorld}.surface.visible(vr.testWall_rightTriangles{vr.currentWorld})=false;
end

%% log and DAQ

if ~vr.debugMode
    vr = initializeDAQ(vr);
    vr.iterationSig=0;
end

vr = initializeLog(vr,'C:\Users\tankadmin\Desktop\virmenLogs_Yao\');

if strcmp(vr.saveLogFile, 'y')
    %first trial info
    fwrite(vr.fid1, [vr.trialNUM vr.sampleCueSequence(vr.trialNUM) vr.leftCueSequence(vr.trialNUM) vr.rightCueSequence(vr.trialNUM)],'double');
end
%% 




% --- RUNTIME code: executes on every iteration of the ViRMEn engine.

function vr = runtimeCodeFun(vr)

%first trial
if vr.iterations==1
    
    if ~vr.debugMode
        turnOnTrial(vr);
    end
    if strcmp(vr.saveLogFile, 'y')
        timeStamp = now;
        fwrite(vr.fid1, timeStamp, 'double');
    end
    sendToUDPforVR(vr, num2str(vr.trialSequence(vr.trialNUM)));
end

%first 10 trials
if vr.iterations<=10
    vr.dp=[0 0 0 0];
end

%dark area
if vr.position(2)<0
    vr.dp=[0 max(0,vr.dp(2)) 0 0];
end
if vr.position(2)>0&&vr.position(2)+vr.dp(2)<0
    vr.dp(2)=0.001-vr.position(2);
end

if vr.hideWall
    %sample cue area
    if ~vr.inSampleCueArea
        if vr.position(2)>=vr.sampleCueLine1&&vr.position(2)<=vr.sampleCueLine2
            vr.inSampleCueArea=true;
            vr.cue=vr.sampleCueSequence(vr.trialNUM);
            vr.worlds{vr.currentWorld}.surface.visible(vr.sampleCueWallTriangles{vr.currentWorld})=true;
        end
    else
        if vr.position(2)<vr.sampleCueLine1||vr.position(2)>vr.sampleCueLine2
            vr.inSampleCueArea=false;
            vr.cue=0;
            vr.worlds{vr.currentWorld}.surface.visible(vr.sampleCueWallTriangles{vr.currentWorld})=false;
        end
    end
    
    %test cue area
    if ~vr.inTestCueArea
        if vr.position(2)>=vr.testCueLine
            vr.inTestCueArea=true;
            %left cue indicated at this moment
            vr.cue=vr.leftCueSequence(vr.trialNUM);
            vr.worlds{vr.currentWorld}.surface.visible(vr.testWall_leftTriangles{vr.currentWorld})=true;
            vr.worlds{vr.currentWorld}.surface.visible(vr.testWall_rightTriangles{vr.currentWorld})=true;
        end
    else
        if vr.position(2)<vr.testCueLine
            vr.inTestCueArea=false;
            vr.cue=0;
            vr.worlds{vr.currentWorld}.surface.visible(vr.testWall_leftTriangles{vr.currentWorld})=false;
            vr.worlds{vr.currentWorld}.surface.visible(vr.testWall_rightTriangles{vr.currentWorld})=false;
        end
    end
end

%near reward site
if vr.noRewardWaiting
    if ~vr.inRewardArea
        if ~vr.inNearRewardArea
            if abs(vr.position(1))>=vr.nearRewardLine;
                vr.inNearRewardArea=true;
                vr.t_inNearRewardArea=tic;
            end
        else
            if abs(vr.position(1))>=vr.nearRewardLine;
                if toc(vr.t_inNearRewardArea)>=vr.rewardWaitingTime
                    vr.dp(1:2)=0;
                    if vr.position(1)<0
                        vr.position(1)=-vr.rewardLocation_x;
                    else
                        vr.position(1)=vr.rewardLocation_x;
                    end
                    vr.position(2)=vr.rewardLocation_y;
                end
            else
                vr.inNearRewardArea=false;
                clear vr.t_inNearRewardArea;
            end
        end
    end
end
           
%reward site
if ~vr.rewardDelivered
   if ~vr.inRewardArea
       if abs(vr.position(1))>=vr.rewardLine;
           vr.inRewardArea=true;
           %right cue indicated at this moment
           vr.cue=vr.rightCueSequence(vr.trialNUM);
           vr.tRewardStart=tic;
           
           %stuck here
           vr.dp(1:2)=0;
           
           timeStamp=now;
           
           if (vr.trialSequence(vr.trialNUM)==1&&vr.position(1)<0)|| ...
              (vr.trialSequence(vr.trialNUM)==2&&vr.position(1)>0)
               if ~vr.debugMode
                 turnOnReward(vr);
               end
               vr.ITIDur=3;
               
               %reward yes
               sendToUDPforVR(vr, 'y');
               if strcmp(vr.saveLogFile, 'y')
                   fwrite(vr.fid1, [timeStamp 1], 'double');
               end
           else
               %warning
               beep;
               vr.ITIDur=6;
               
               %reward no
               sendToUDPforVR(vr, 'n');
               if strcmp(vr.saveLogFile, 'y')
                   fwrite(vr.fid1, [timeStamp 0], 'double');
               end
           end
       end
   else
       if toc(vr.tRewardStart)>=vr.rewardDur
           if ~vr.debugMode
               turnOffReward(vr);
           end
           vr.rewardDelivered=true;
       end
       vr.dp(1:2)=0;
   end
end

%trial end pause and ITI
if ~vr.trialEndPauseOver
    if ~vr.inTrialEndPause
        if vr.rewardDelivered
            vr.inTrialEndPause=true;
            vr.dp(1:2)=0;
            vr.tTrialEndPauseStart=tic;
        end
    else
        if toc(vr.tTrialEndPauseStart)>=vr.trialEndPauseDur
            vr.trialEndPauseOver=true;
            % trial end time
            if ~vr.debugMode
                turnOffTrial(vr);
            end
        end
        vr.dp(1:2)=0;
    end
else
    if ~vr.inITI
         vr.trialNUM=vr.trialNUM+1;
         
         if vr.trialNUM>vr.totalTrials
             vr.experimentEnded=true;
         else
             vr.inITI=true;
             vr.tITIstart=tic;
             
             vr.currentWorld=vr.worldSequence(vr.trialNUM);
             vr.position = vr.worlds{vr.currentWorld}.startLocation;
             vr.dp=0;
             vr.worlds{vr.currentWorld}.surface.colors(4,:)=0;
         
             vr.cue=0;
         end
    else
        if toc(vr.tITIstart)>=vr.ITIDur
            
            %reset parameters
            vr.worlds{vr.currentWorld}.surface.colors(4,:)=1;
            if vr.hideWall
                vr.worlds{vr.currentWorld}.surface.visible(vr.sampleCueWallTriangles{vr.currentWorld})=false;
                vr.worlds{vr.currentWorld}.surface.visible(vr.testWall_leftTriangles{vr.currentWorld})=false;
                vr.worlds{vr.currentWorld}.surface.visible(vr.testWall_rightTriangles{vr.currentWorld})=false;
            end
            
            vr.inSampleCueArea=false;
            vr.inTestCueArea=false;
            
            vr.inNearRewardArea=false;
            
            vr.inRewardArea=false;
            vr.rewardDelivered=false;
            
            vr.trialEndPauseOver=false;
            vr.inTrialEndPause=false;
            
            vr.inITI=false;
            
            % trial start
            if ~vr.debugMode
                turnOnTrial(vr);
            end
            
            %trial info
            timeStamp=now;
            if strcmp(vr.saveLogFile, 'y')
                fwrite(vr.fid1, [vr.trialNUM vr.sampleCueSequence(vr.trialNUM) vr.leftCueSequence(vr.trialNUM) vr.rightCueSequence(vr.trialNUM) timeStamp],'double');
            end
            sendToUDPforVR(vr, num2str(vr.trialSequence(vr.trialNUM)));
        end
        vr.dp=0;
    end
end

% update ouput
if ~vr.debugMode
    updateDAQ(vr);
    vr.iterationSig=~vr.iterationSig;
    updateVRiterationSig(vr);
end

if strcmp(vr.saveLogFile, 'y')
    timeStamp=now;
    fwrite(vr.fid2, [timeStamp vr.position([1 2 4]) vr.velocity([1 2 4])],'double');
end
        
%% 
% --- TERMINATION code: executes after the ViRMEn engine stops.
function vr = terminationCodeFun(vr)

if ~vr.debugMode
    turnOffTrial(vr);
    
    resetVRiterationSig(vr);
    
    % terminate DAQ
    terminateDAQ(vr);
    
    % close Arduino
    delete(vr.mr);
end

terminateUDPforVR(vr);

if strcmp(vr.saveLogFile, 'y')
    % close log
    terminateLog(vr);
end
