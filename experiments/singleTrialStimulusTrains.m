function singleTrialStimulusTrains(file)

if nargin < 1
  file     = 'TrajectoryFile_1'; 
end

savefile = ['stimulus_trains_' file '.mat'];
cd C:\Users\User\OneDrive\Research\MatLab\ViRMEn\movements
load(file)

cd C:\Users\User\OneDrive\Research\MatLab\ViRMEn\experiments\protocols
% load('stimulus_trains_PoissonBlocksReboot3m_20sets_dup0p5_pan100_n400_x4.mat')
load('stimulus_trains_PoissonBlocksCondensed3m_20sets_dup0p5_pan100_n400_x10.mat')

cuePos        = {cuePos_L, cuePos_R};
cues          = [cuePos_L, cuePos_R];
cueCombo      = zeros(2,numel(cuePos_L)+numel(cuePos_R)); 
cueCombo(1,:) = ismember(sort(cues),cuePos_L);
cueCombo(2,:) = ismember(sort(cues),cuePos_R);
nSalient      = max([numel(cuePos_L) numel(cuePos_R)]);
nDistract     = min([numel(cuePos_L) numel(cuePos_R)]);

poissonStimuliTemp = class2struct(poissonStimuli);
poissonStimuliTemp = rmfield(poissonStimuliTemp,'CHOICES');
poissonStimuliTemp = rmfield(poissonStimuliTemp,'MAX_RETRIES');

for jj = 1:size(poissonStimuliTemp.panSession,1) % maze
    for ii = 1:size(poissonStimuliTemp.panSession,2) % stim ID
        
        poissonStimuliTemp.panSession(jj,ii).cuePos    = cuePos;
        poissonStimuliTemp.panSession(jj,ii).cueCombo  = cueCombo;
        poissonStimuliTemp.panSession(jj,ii).nSalient  = nSalient;
        poissonStimuliTemp.panSession(jj,ii).nDistract = nDistract;
        
    end
    for ii = 1:size(poissonStimuliTemp.perSession,2) % stim ID
        for kk = 1:size(poissonStimuliTemp.perSession,3)
            poissonStimuliTemp.perSession(jj,ii,kk).cuePos    = cuePos;
            poissonStimuliTemp.perSession(jj,ii,kk).cueCombo  = cueCombo;
            poissonStimuliTemp.perSession(jj,ii,kk).nSalient  = nSalient;
            poissonStimuliTemp.perSession(jj,ii,kk).nDistract = nDistract;
        end
    end
end

poissonStimuli = PoissonStimulusTrain();
poissonStimuli.copyStruct(poissonStimuliTemp);
forcedTrials   = 1;
forcedTypes    = Choice(1 + (numel(cuePos_R) > numel(cuePos_L)));

save(savefile,'poissonStimuli','forcedTrials','forcedTypes')