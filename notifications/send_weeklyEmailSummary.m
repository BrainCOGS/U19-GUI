function send_weeklyEmailSummary

% send_weeklyEmailSummary
% send automated summary email of mouse data for previous week
% called by notificationTimer

%% pull from database
dataBaseObj         = AnimalDatabase;
overview            = dataBaseObj.pullOverview; % pull from spreadsheet
allmice             = dataBaseObj.pullAnimalList; % pull from spreadsheet

%% initialize
userInfo            = {};
msg                 = {};
msgHeader           = 'Hi %s,\n\nHere is the weekely summary for your mice:\n\n';
mouseSeparator      = '--------------------------------------';
includeFields       = {'received';'weight';'performance';'mainMazeID';'rigName';'actItems';'comments'};
numTabs             = [2           1        2             2            1         2          2];

%% compose user-specific messages including only animals that were active within the previous week
for iUser = 1:numel(overview.Researchers)
  % select only last week' data
  if isempty(allmice{iUser}); continue; end % skip users with no mice
  mice              = allmice{iUser};
  logs              = dataBaseObj.pullDailyLogs(overview.Researchers(iUser).ID); % pull logs for this researcher
  hasAnyData        = cellfun(@(x)(~isempty(x)),logs,'UniformOutput',false);
  hasAnyData        = [hasAnyData{:}];
  logs              = logs(hasAnyData);
  mice              = mice(hasAnyData);
  lastDate          = cellfun(@(x)(x(end).date),logs,'UniformOutput',false);
  activeLastWeek    = cellfun(@(x)(floor(now()) - datenum(x) <= 7),lastDate,'UniformOutput',false);
  activeLastWeek    = [activeLastWeek{:}];
  logs              = logs(activeLastWeek);
  mice              = mice(activeLastWeek);
  
  if numel(logs) < 1; continue; end % skip users with no activity in the last week
  
  % write message in table format per animal
  userInfo{end+1}   = overview.Researchers(iUser);
  msg{end+1}        = sprintf('%s%s\n',sprintf(msgHeader,overview.Researchers(iUser).ID),mouseSeparator);
  for iMouse = 1:numel(logs)
    dates    = {logs{iMouse}(:).date};
    lastWeek = cellfun(@(x)(floor(now()) - datenum(x) <= 7),dates,'UniformOutput',false);
    lastWeek = find([lastWeek{:}]);
    
    msg{end} = sprintf('%s%s\n\nDATE\t',msg{end},mice(iMouse).ID);
    for iField = 1:numel(includeFields)
      msg{end} = sprintf('%s%s\t',msg{end},upper(includeFields{iField}));
    end
    msg{end} = sprintf('%s\n\n',msg{end});
    for iDate = 1:numel(lastWeek)
      msg{end} = sprintf('%s%d-%d\t',msg{end},logs{iMouse}(lastWeek(iDate)).date(2),logs{iMouse}(lastWeek(iDate)).date(3));
      for iField = 1:numel(includeFields)
        thisval = eval(sprintf('logs{iMouse}(lastWeek(iDate)).%s',includeFields{iField}));
        if ischar(thisval)
          msg{end} = sprintf('%s%s',msg{end},thisval);
        else
          msg{end} = sprintf('%s%.1f',msg{end},thisval);
        end
        for iTab = 1:numTabs(iField)
          msg{end} = sprintf('%s\t',msg{end});
        end
      end
      msg{end} = sprintf('%s\n',msg{end});
    end
    msg{end} = sprintf('%s\n%s\n',msg{end},mouseSeparator);
  end
  
end

%% send email
send_notification(userInfo,msg,'email','Automated weekly mouse summary')