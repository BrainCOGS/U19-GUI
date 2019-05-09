function writeTrainingDataToDatabase(log,vr)

%% mouse & experimenter
dbase        = AnimalDatabase(false); % open communications
% manageNotificationTimers('stop'); % prevent notification timers from running in virmen computers
mouse        = log.animal.name; % mouse
logname      = log.logFile; % path will be used to infer experimenter
users        = dbase.pullOverview; % get user info from database
userList     = {users.Researchers(:).ID}; 
userIdx      = cellfun(@(x)(~isempty(strfind(upper(logname),upper(x)))),userList,'UniformOutput',false);
userIdx      = [userIdx{:}];
experimenter = users.Researchers(userIdx).ID; % experimenter

% if animal is not on database, create entry and warn user
[msg,mouse]  = doubleCheckAnimalExists(mouse,experimenter,dbase);
if ~isempty(msg); warning('DATABASE:writeTrainingDataToDatabase',msg); return; end

%% virmen, rig data
rwamount     = round(10*sum([log.block(:).rewardMiL]))/10; 
lg           = summarizeTrialInfo(log);
startTime    = AnimalDatabase.datenum2time(log.session.start);
endTime      = AnimalDatabase.datenum2time(log.session.end);
experInfo    = {[char(log.version.code) '.m'],[char(log.version.name) '.mat'],char(log.animal.protocol)};
versionInfo  = {num2str(log.version.mazeVersion),num2str(log.version.codeVersion)};
stimBank     = log.animal.stimulusBank;
stimSet      = log.animal.stimulusSet;
rigname      = log.version.rig.rig;
if ~isfield(vr,'squal'); vr.squal = nan; end 

%% write
dbase.pushDailyInfo(experimenter,    mouse,           ...
                   'earned',         rwamount,        ...
                   'performance',    lg.perf,         ...
                   'mazeID',         lg.currMaze,     ...
                   'mainMazeID',     lg.mainMazeID,   ...
                   'numTowersR',     lg.numTowersR,   ...
                   'numTowersL',     lg.numTowersL,   ...
                   'trialType',      lg.trialType,    ...
                   'choice',         lg.choice,       ...
                   'behavProtocol',  experInfo,       ...
                   'versionInfo',    versionInfo,     ...
                   'stimulusBank',   stimBank,        ...
                   'stimulusSet',    stimSet,         ...
                   'rigName',        rigname,         ...
                   'squal',          vr.squal,        ...
                   'trainStart',     startTime,       ...
                   'trainEnd',       endTime          ...
                   );
delete(dbase);

end

%% if animal is not in database create entry and issue warning
function [msg,mouse]  = doubleCheckAnimalExists(mouse,experimenter,dbase)

mouseList = dbase.pullAnimalList(experimenter);
mouseList = {mouseList(:).ID};

if sum(strcmpi(mouseList,mouse)) > 0
  msg   = [];
  mouse = mouseList{strcmpi(mouseList,mouse)};
else
%   dbase.pushAnimalInfo(experimenter,mouse);
  msg = ['---- ATTENTION: animal ' mouse ' for researcher ' experimenter ' not found in database. Cannot write to spreadsheet. Please add using the GUI ----'];
end

end

%% calculate performance in main maze trials
function lg = summarizeTrialInfo(log)

% trial info
lg.currMaze   = [];
lg.trialType  = [];
lg.choice     = [];
lg.numTowersR = [];
lg.numTowersL = [];

tc = 0; % overall counter to concatenate blocks
for b = 1:numel(log.block) % main maze blocks
  
  % there is a bug that generates empty blocks
  if isempty(log.block(b).trial); continue; end
  
  for t = 1:numel(log.block(b).trial) % trials within block
    if  (log.block(b).trial(t).choice == Choice.nil                            ...
        && log.block(b).trial(t).time(log.block(b).trial(t).iterations) < 60 ) ...
        || isempty(log.block(b).trial(t).excessTravel)
      fprintf('b:%d, t:%d',b,t)
      lg.choice(tc+t) = single(-1); 
      
    else
      
      lg.choice(tc+t) = single(log.block(b).trial(t).choice); 
      
    end
    
    lg.currMaze(tc+t)   = log.block(b).mazeID;
    lg.trialType(tc+t)  = single(log.block(b).trial(t).trialType); 
    lg.numTowersR(tc+t) = numel(log.block(b).trial(t).cuePos{2}); 
    lg.numTowersL(tc+t) = numel(log.block(b).trial(t).cuePos{1}); 
    
  end
  
  tc = tc + t; % udpate total number of trials
end

lg.mainMazeID          = max(lg.currMaze);
mainMaze               = lg.currMaze == lg.mainMazeID;
lg.currMaze(~mainMaze) = -lg.currMaze(~mainMaze);
lg.perf                = sum(lg.choice(mainMaze) == lg.trialType(mainMaze))./sum(mainMaze) * 100;

end