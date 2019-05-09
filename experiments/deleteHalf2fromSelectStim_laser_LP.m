clear
% cd /Users/lucas/Documents/Princeton/code/TankMouseVR/experiments/protocols
load('stimulus_trains_PoissonBlocksReboot3m_20sets_dup0p5_pan100_n400_x4.mat')

poissonStimuliTemp = class2struct(poissonStimuli);
poissonStimuliTemp = rmfield(poissonStimuliTemp,'CHOICES');
poissonStimuliTemp = rmfield(poissonStimuliTemp,'MAX_RETRIES');

md = 4; % delete 2nd half of cues every md stimulus for matched control to laser trials
badidx_pan = []; badidx_per = [];
for jj = 1:size(poissonStimuliTemp.panSession,1) % maze
    for ii = md:md:size(poissonStimuliTemp.panSession,2) % stim ID
        
        % copy previous stim
        poissonStimuliTemp.panSession(jj,ii) = poissonStimuliTemp.panSession(jj,ii-1);
        
        % delete stimuli in second half and update parameters
        poissonStimuliTemp.panSession(jj,ii).index = poissonStimuliTemp.panSession(jj,ii).index-1; % negative for panSession
        
        poissonStimuliTemp.panSession(jj,ii).cuePos{1} = sort(poissonStimuliTemp.panSession(jj,ii).cuePos{1});
        poissonStimuliTemp.panSession(jj,ii).cuePos{2} = sort(poissonStimuliTemp.panSession(jj,ii).cuePos{2});
        
        idxR = find(poissonStimuliTemp.panSession(jj,ii).cuePos{1} > poissonStimuliTemp.config(jj).lCue/2);
        idxL = find(poissonStimuliTemp.panSession(jj,ii).cuePos{2} > poissonStimuliTemp.config(jj).lCue/2);
        
        poissonStimuliTemp.panSession(jj,ii).cuePos{1}(idxR) = [];
        poissonStimuliTemp.panSession(jj,ii).cuePos{2}(idxL) = [];
        
        poissonStimuliTemp.panSession(jj,ii).nSalient  = max([numel(poissonStimuliTemp.panSession(jj,ii).cuePos{1}) numel(poissonStimuliTemp.panSession(jj,ii).cuePos{2})]);
        poissonStimuliTemp.panSession(jj,ii).nDistract = min([numel(poissonStimuliTemp.panSession(jj,ii).cuePos{1}) numel(poissonStimuliTemp.panSession(jj,ii).cuePos{2})]);
        
        if poissonStimuliTemp.panSession(jj,ii).nSalient <= poissonStimuliTemp.panSession(jj,ii).nDistract
            badidx_pan = [badidx_pan; ii jj];
        end
        
        idxR2 = find(poissonStimuliTemp.panSession(jj,ii).cueCombo(1,:)==1);
        idxL2 = find(poissonStimuliTemp.panSession(jj,ii).cueCombo(2,:)==1);
        poissonStimuliTemp.panSession(jj,ii).cueCombo(1,idxR2(idxR)) = 0;
        poissonStimuliTemp.panSession(jj,ii).cueCombo(2,idxL2(idxL)) = 0;
        temp = find(sum(poissonStimuliTemp.panSession(jj,ii).cueCombo)==0);
        poissonStimuliTemp.panSession(jj,ii).cueCombo(:,temp) = [];
    end
    for ii = md:md:size(poissonStimuliTemp.perSession,2) % stim ID
        for kk = 1:size(poissonStimuliTemp.perSession,3)
            % copy previous stim
            poissonStimuliTemp.perSession(jj,ii,kk) = poissonStimuliTemp.perSession(jj,ii-1,kk);
            
            % delete stimuli in second half and update parameters
            poissonStimuliTemp.perSession(jj,ii,kk).index = poissonStimuliTemp.perSession(jj,ii,kk).index+1; % negative for perSession
            
            poissonStimuliTemp.perSession(jj,ii,kk).cuePos{1} = sort(poissonStimuliTemp.perSession(jj,ii,kk).cuePos{1});
            poissonStimuliTemp.perSession(jj,ii,kk).cuePos{2} = sort(poissonStimuliTemp.perSession(jj,ii,kk).cuePos{2});
            
            idxR = find(poissonStimuliTemp.perSession(jj,ii,kk).cuePos{1} > poissonStimuliTemp.config(jj).lCue/2);
            idxL = find(poissonStimuliTemp.perSession(jj,ii,kk).cuePos{2} > poissonStimuliTemp.config(jj).lCue/2);
            
            poissonStimuliTemp.perSession(jj,ii,kk).cuePos{1}(idxR) = [];
            poissonStimuliTemp.perSession(jj,ii,kk).cuePos{2}(idxL) = [];
            
            poissonStimuliTemp.perSession(jj,ii,kk).nSalient  = max([numel(poissonStimuliTemp.perSession(jj,ii,kk).cuePos{1}) numel(poissonStimuliTemp.perSession(jj,ii,kk).cuePos{2})]);
            poissonStimuliTemp.perSession(jj,ii,kk).nDistract = min([numel(poissonStimuliTemp.perSession(jj,ii,kk).cuePos{1}) numel(poissonStimuliTemp.perSession(jj,ii,kk).cuePos{2})]);
            
            if poissonStimuliTemp.perSession(jj,ii,kk).nSalient <= poissonStimuliTemp.perSession(jj,ii,kk).nDistract
                badidx_per = [badidx_per; ii jj kk];
            end
            
            idxR2 = find(poissonStimuliTemp.perSession(jj,ii,kk).cueCombo(1,:)==1);
            idxL2 = find(poissonStimuliTemp.perSession(jj,ii,kk).cueCombo(2,:)==1);
            poissonStimuliTemp.perSession(jj,ii,kk).cueCombo(1,idxR2(idxR)) = 0;
            poissonStimuliTemp.perSession(jj,ii,kk).cueCombo(2,idxL2(idxL)) = 0;
            temp = find(sum(poissonStimuliTemp.perSession(jj,ii,kk).cueCombo)==0);
            poissonStimuliTemp.perSession(jj,ii,kk).cueCombo(:,temp) = [];
        end
    end
end

% replace trials with equal number of targets and diostractors for advanced
% mazes
for ii = 1:size(badidx_pan,1)
    if badidx_pan(ii,2) >=9
        poissonStimuliTemp.panSession(badidx_pan(ii,2),badidx_pan(ii,1)-1) = poissonStimuliTemp.panSession(badidx_pan(ii,2),badidx_pan(ii,1)+md*2-1);
        poissonStimuliTemp.panSession(badidx_pan(ii,2),badidx_pan(ii,1)) = poissonStimuliTemp.panSession(badidx_pan(ii,2),badidx_pan(ii,1)+md*2);
    end
end

for ii = 1:size(badidx_per,1)
    if badidx_per(ii,2) >=9
        idx = find(badidx_per(:,1)==badidx_per(ii,1) & badidx_per(:,2)==badidx_per(ii,2));
        badset = badidx_per(idx,3);
        goodset = setdiff(1:size(poissonStimuliTemp.perSession,3),badset);
        poissonStimuliTemp.perSession(badidx_per(ii,2),badidx_per(ii,1)-1,badidx_per(ii,3)) = poissonStimuliTemp.perSession(badidx_per(ii,2),badidx_per(ii,1)-1,goodset(1));
        poissonStimuliTemp.perSession(badidx_per(ii,2),badidx_per(ii,1),badidx_per(ii,3)) = poissonStimuliTemp.perSession(badidx_per(ii,2),badidx_per(ii,1),goodset(1));
    end
end

% % sanity check
% badidx_pan = []; badidx_per = [];
% for jj = 9:size(poissonStimuli.panSession,1) % maze
%     for ii = md:md:size(poissonStimuli.panSession,2) % stim ID
% 
%         nSalient  = max([numel(poissonStimuli.panSession(jj,ii).cuePos{1}) numel(poissonStimuli.panSession(jj,ii).cuePos{2})]);
%         nDistract = min([numel(poissonStimuli.panSession(jj,ii).cuePos{1}) numel(poissonStimuli.panSession(jj,ii).cuePos{2})]);
%         
%         if nSalient <= nDistract
%             badidx_pan = [badidx_pan; ii jj];
%         end
%     end
%     for ii = md:md:size(poissonStimuli.perSession,2) % stim ID
%         for kk = 1:size(poissonStimuli.perSession,3)
%            
%            nSalient  = max([numel(poissonStimuli.perSession(jj,ii,kk).cuePos{1}) numel(poissonStimuli.perSession(jj,ii,kk).cuePos{2})]);
%            nDistract = min([numel(poissonStimuli.perSession(jj,ii,kk).cuePos{1}) numel(poissonStimuli.perSession(jj,ii,kk).cuePos{2})]);
%             
%             if nSalient <= nDistract
%                 badidx_per = [badidx_per; ii jj kk];
%             end
% 
%         end
%     end
% end

poissonStimuli = PoissonStimulusTrain();
poissonStimuli.copyStruct(poissonStimuliTemp);

save stimulus_trains_PoissonBlocksReboot3m_laser_deleteHalf2_20sets_dup0p5_pan100_n400_x4.mat poissonStimuli