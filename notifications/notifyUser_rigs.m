function vr = notifyUser_rigs(vr)

% vr = notifyUser_rigs(vr)

try
%% get info from database
dbase        = AnimalDatabase; % open comm
dbase.pullOverview;
manageNotificationTimers('stop'); % prevent notification timers from running in virmen computers
mouse        = vr.protocol.animal.name; % mouse name
notifyInfo   = getNotifyInfo(vr,dbase); % nested function to determine who gets notified
rwamount     = vr.protocol.totalRewards; % rw amount for notification
message      = sprintf('%s is done, received %1.1fmL', mouse, rwamount);

%% notify relevant users via preferred method
send_notification(notifyInfo, message, 'preferred');
catch
  warning('unable to notify user')
end
end

%% determine who to notify and retrieve contact info
function notifyInfo = getNotifyInfo(vr,dbase)

% match user list to log file path
logname         = vr.logger.logFile;
users           = dbase.pullOverview;
userList        = {users.Researchers(:).ID};
isUser          = cellfun(@(x)(~isempty(strfind(upper(logname),x))),upper(userList));
userID          = userList(isUser);
researcherInfo  = dbase.findResearcher(userID);

% if researcher doesn't have techs, they should be notified
if strcmpi(researcherInfo.TechResponsibility,'no')
  notifyInfo    = researcherInfo;
  return;
end

% is the mouse in the database?
mice            = dbase.pullAnimalList(userID);
if iscell(mice); mice = mice{1}; end
mouseIDs        = {mice(:).ID};
thismouse       = strcmpi(mouseIDs,vr.protocol.animal.name);

% if mouse is not in database default to primary tech, then to researcher
% if tech is not working today
if sum(thismouse) == 0
  notifyInfo    = dbase.techOnDuty;  
  if ~strcmpi(notifyInfo.primaryTech,'yes')
    notifyInfo  = researcherInfo;
  end
  return;
end

% else, is this an experiment or a training session?
updates         = dbase.whatIsThePlan(mice(thismouse),false);
[~,todayIs]     = weekday(now);
dayIdx          = strcmpi({users.DutyRoster.Day},todayIs);
techTrain       = updates.techDuties(dayIdx) == Responsibility.Train;

% if training, notify tech, if not, notify researcher
if techTrain
  notifyInfo    = dbase.techOnDuty;  
  if ~strcmpi(notifyInfo.primaryTech,'yes')
    notifyInfo  = researcherInfo;
  end
else 
  notifyInfo    = researcherInfo;
end

end