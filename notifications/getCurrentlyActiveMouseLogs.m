function [logs,mice] = getCurrentlyActiveMouseLogs(whoIsAsking,ownerID,dataBaseObj)

% [logs,mouseIDs] = getCurrentlyActiveMouseLogs(whoIsAsking,ownerID,dataBaseObj)
% this will select logs of mice under active restriction monitoring and
% return them, as well as their general info sheets
% whoIsAsking is person who needs notification, ownerID is the ID for the
% researcher whose animals are being querried, databaseObj is obtained from
% AnimalDatabase() (optional)

%% pull data
if nargin < 3
  dataBaseObj  = AnimalDatabase; dataBaseObj.pullOverview;
end

%% get mouse status
mice         = dataBaseObj.pullAnimalList(ownerID);
logs         = dataBaseObj.pullDailyLogs(ownerID);
needsWater   = dataBaseObj.shouldICare(mice,whoIsAsking,true);
logs         = logs(needsWater);
mice         = mice(needsWater);

