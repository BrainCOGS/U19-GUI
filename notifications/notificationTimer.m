function notificationTimer(dataBaseObj)

% notificationTimer
% keeps several timers for automatic notifications:
%     weekly email summary of mouse training, weight, performance
%     daily checks for mouse weighing and cage returns with user-specific
%       times, with ensuing notification chains if needed
% ideally should always be running in the background

%% global vars
global overview weeklyDigestTimer researcherDailyTimer

%% update database
% dataBaseObj         = AnimalDatabase;
overview            = dataBaseObj.pullOverview; % pull from spreadsheet

%% stop all running timers
manageNotificationTimers('stop'); 

%% set a hourly timer to update database
databaseUpdateTimer = timer('ExecutionMode',  'fixedRate'               ...
                           ,'BusyMode',       'drop'                    ...
                           ,'Name',           'databaseUpdate'          ...
                           ,'Period',         3600                      ...
                           ,'TasksToExecute', Inf                       ...
                           ,'TimerFcn',       {@updateDatabase,dataBaseObj}           ...
                           );
start(databaseUpdateTimer);

%% daily checks at user-specified times
dailyCheckDelay      = round([arrayfun(@getDailyUserDelay,overview.Researchers) ...
                             arrayfun(@getDailyUserDelay,overview.Technicians) ...
                            ]);
researcherDailyTimer = timer('ExecutionMode',  'singleShot'         ...
                            ,'BusyMode',       'drop'               ...
                            ,'Name',           'nextDailyCheck'     ...
                            ,'startDelay',     min(dailyCheckDelay) ...
                            ,'TasksToExecute', 1                    ...
                            ,'TimerFcn',       {@dailyUserCheck,dataBaseObj}      ...
                            );
start(researcherDailyTimer);

%% start weekly email summary timer, resets automatically
weeklyDigestDelay   = getWeeklyDigestDelay(overview);
weeklyDigestTimer   = timer('ExecutionMode',  'singleShot'              ...
                           ,'BusyMode',       'drop'                    ...
                           ,'Name',           'weeklyDigest'            ...
                           ,'startDelay',     round(weeklyDigestDelay)  ...
                           ,'TasksToExecute', 1                         ...
                           ,'TimerFcn',       {@sendWeeklyDigest,dataBaseObj}         ...
                           );
start(weeklyDigestTimer);
                         
end

%% check cage, watering situation, notify if necessary
function dailyUserCheck(obj,event,dataBaseObj)

global overview 
updateDatabase([],[],dataBaseObj);

% timer event
eventHour   = double(event.Data.time(4));
eventMin    = double(event.Data.time(5));

% determine which researchers to check (within a minute of desired time)
timeOfDay   = {overview.Researchers(:).DayCutoffTime};
checkUser   = cellfun(@(x)(x(1)==eventHour && abs(x(2)-eventMin)<=1),timeOfDay,'UniformOutput',false);
checkUser   = [checkUser{:}];

% run checks after enforcing a stochastic timer to avoid different
% computers sending the same notification (this works because we keep track
% of them in the database)
if sum(checkUser) > 0
  rng('shuffle')
  idx       = find(checkUser);
  delays    = 0:30:180;
  for iUser = 1:numel(idx)
    thisdelay        = delays(randi(numel(delays)));
    stochasticTimer  = timer('ExecutionMode',  'singleShot'         ...
                            ,'BusyMode',       'drop'               ...
                            ,'Name',           'stochasticPause'    ...
                            ,'startDelay',     thisdelay            ...
                            ,'TasksToExecute', 1                    ...
                            ,'TimerFcn',       {@triggerNotifications,overview.Researchers(idx(iUser)),dataBaseObj}      ...
                            );
    start(stochasticTimer);
  end
end

% determine which tech to check
techOnDuty  = dataBaseObj.techOnDuty;
timeOfDay   = techOnDuty.DayCutoffTime;
checkUser   = timeOfDay(1)==eventHour & (timeOfDay(2)-eventMin)<=1;

% run checks after enforcing a stochastic timer to avoid different
% computers sending the same notification (this works because we keep track
% of them in the database)
if checkUser
  rng('shuffle')
  delays           = 0:30:180;
  thisdelay        = delays(randi(numel(delays)));
  stochasticTimer  = timer('ExecutionMode',  'singleShot'         ...
                          ,'BusyMode',       'drop'               ...
                          ,'Name',           'stochasticPause'    ...
                          ,'startDelay',     thisdelay            ...
                          ,'TasksToExecute', 1                    ...
                          ,'TimerFcn',       {@triggerNotifications,techOnDuty,dataBaseObj}      ...
                          );
  start(stochasticTimer);
end

end

%% trigger checks after stochastic delay
function triggerNotifications(obj,event,userInfo,dataBaseObj)

checkMouseWeighing(userInfo,dataBaseObj);
checkCageReturn(userInfo,dataBaseObj);
checkActionItems(userInfo,dataBaseObj);
resetDailyCheckTimer(dataBaseObj);

stop(obj)
delete(obj)
clear obj

end

%% send digest and reset timer
function sendWeeklyDigest(obj,event,dataBaseObj)

updateDatabase([],[],dataBaseObj);
send_weeklyEmailSummary;
resetWeeklyDigestTimer(dataBaseObj);

end

%% reset timer after single-execution daily reserach cage check timer
function resetDailyCheckTimer(dataBaseObj)

global overview researcherDailyTimer

try
stop(researcherDailyTimer)
delete(researcherDailyTimer)
end
updateDatabase([],[],dataBaseObj);

dailyCheckDelay      = round([arrayfun(@getDailyUserDelay,overview.Researchers) ...
                              arrayfun(@getDailyUserDelay,overview.Technicians) ...
                             ]);
researcherDailyTimer = timer('ExecutionMode',  'singleShot'         ...
                            ,'BusyMode',       'drop'               ...
                            ,'Name',           'nextDailyCheck'     ...
                            ,'startDelay',     min(dailyCheckDelay) ...
                            ,'TasksToExecute', 1                    ...
                            ,'TimerFcn',       {@dailyUserCheck,dataBaseObj}      ...
                            );
start(researcherDailyTimer);

end

%% reset timer after single-execution weekly timer
function resetWeeklyDigestTimer(dataBaseObj)

global overview weeklyDigestTimer
stop(weeklyDigestTimer)
delete(weeklyDigestTimer)
updateDatabase([],[],dataBaseObj);
weeklyDigestDelay   = getWeeklyDigestDelay(overview);
weeklyDigestTimer   = timer('ExecutionMode',  'singleShot'              ...
                           ,'BusyMode',       'drop'                    ...
                           ,'startDelay',     weeklyDigestDelay         ...
                           ,'Name',           'weeklyDigest'            ...
                           ,'TasksToExecute', 1                         ...
                           ,'TimerFcn',       {@sendWeeklyDigest,dataBaseObj}         ...
                           );
start(weeklyDigestTimer);

end

%% update database
function updateDatabase(obj,event,dataBaseObj)
global overview
% dataBaseObj         = AnimalDatabase;
overview            = dataBaseObj.pullOverview; % pull from spreadsheet
end

%% get delay in seconds until next weekly notification
function delay = getWeeklyDigestDelay(overview)

%% get day and time digest must be sent 
timeOfDay       = overview.NotificationSettings.WeeklyDigestTime;
dayOfWeek       = overview.NotificationSettings.WeeklyDigestDay;

%% figure out delay
dayLookUp       = {'Sun','Mon','Tue','Wed','Thu','Fri','Sat'};
goalIs          = find(strcmpi(dayLookUp,dayOfWeek));
todayIs         = weekday(now);
nFullDays       = 7 + goalIs - todayIs - 1; % # full days
secLeftToday    = datevec(datetime('tomorrow') - datetime('now'));
secLeftToday    = secLeftToday(4)*3600 + secLeftToday(5)*60 + secLeftToday(6); % seconds till tomorrow
secondsTarget   = timeOfDay(1)*3600 + timeOfDay(2)*60; % seconds into target day

delay           = nFullDays*24*3600 + secLeftToday + secondsTarget;

end

%% get delay in seconds until next daily notification for specific user
function delay = getDailyUserDelay(user)

% get time digest must be sent 
timeOfDay       = user.DayCutoffTime;
secondsTarget   = timeOfDay(1)*3600 + timeOfDay(2)*60;
timeNow         = datevec(datetime('now'));
secElapsedToday = timeNow(4)*3600 + timeNow(5)*60 + timeNow(6); 

delay           = secondsTarget - secElapsedToday;
if delay < 0; delay = 24*3600 + delay; end

end
