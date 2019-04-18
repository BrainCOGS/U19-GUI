function checkMouseWeighing(userInfo,dataBaseObj)

% checkMouseWeighing(userInfo)
% checks if mouse has been weighed
% researcher will be notified for all, tech only for animals for which they
% are directly responsible. If researcher doesn't act within predefined
% deadline, secondary contact gets notified
% userInfo is overview sheet for a specific user, can be either researcher
% or tech

%% get database
if nargin < 2; dataBaseObj = AnimalDatabase; end
overview    = dataBaseObj.pullOverview;

%% figure out if tech or not, will trigger different actions
if isfield(userInfo,'primaryTech')
  techOrResearcher = 'tech';
else
  techOrResearcher = 'researcher';
end

%% check and notify
switch techOrResearcher
  case 'researcher' % will be notified about every cage under their name
    
    %% find animals with missing entries or low weights
    [logs,mice] = getCurrentlyActiveMouseLogs(userInfo,userInfo.ID,dataBaseObj);
    if isempty(mice); return; end
    hasNoData   = cellfun(@(x)(isempty(x)),logs,'UniformOutput',false);
    hasNoData   = [hasNoData{:}];
    notWeighed  = {mice(hasNoData).ID};
    logs        = logs(~hasNoData);
    mice        = mice(~hasNoData);
    lastEntries = cellfun(@(x)(x(end)),logs);
    todayIs     = floor(now());
    hasEntry    = arrayfun(@(x)(datenum(x.date) == todayIs && (~isempty(x.weight) || ~isempty(strfind(x.weightNotice,'Primary')))),lastEntries);
    notWeighed  = [notWeighed {mice(~hasEntry).ID}];

    %% decide who to contact
    deadline           = overview.NotificationSettings.MaxResponseTime;
    whosSecondary      = userInfo.SecondaryContact;
    whosPrimary        = userInfo.ID; 
    if ~strcmpi(userInfo.Presence,'Available')
      secondaryContact = true;
      userInfo         = dataBaseObj.findResearcher(whosSecondary);
    else
      secondaryContact = false;
    end
    
    %% write to spreadsheet to prevent other machines from triggering notification
    for iMouse = 1:numel(notWeighed)
      currNotice = lastEntries(strcmpi({mice(:).ID},notWeighed{iMouse})).weightNotice;
      newNotice  = sprintf('%s - Primary (%s)',currNotice,userInfo.ID);
      if secondaryContact; newNotice = [newNotice '(sub)']; end
      dataBaseObj.pushDailyInfo(whosPrimary, notWeighed{iMouse}, 'weightNotice', newNotice);
    end
      
    %% write and send message about missing weights, and start timer if primary user
    if ~isempty(notWeighed)
      msg = 'The following animals have not been weighed today: ';
      msg = [msg notWeighed{1}];
      if numel(notWeighed) > 1
        mouseList = cellfun(@(x)([', ' x]),notWeighed(2:end) ,'UniformOutput',false);
        mouseList = [mouseList{:}];
        msg = [msg mouseList];
      end
      
      if secondaryContact
        msg = sprintf('Hi %s, you are receiving this message because you are listed as the secondary contact for %s, who is away\n%s.',whosSecondary,whosPrimary,msg);
        send_notification(userInfo,msg,'all');
      else
        msg = sprintf('Hi %s, \n%s.\nIf you do not resolve this issue within %d min your secondary contact will be reached',whosPrimary,msg,deadline);
        send_notification(userInfo,msg,'all');

        %% start timer
        noticeDay          = floor(now()); 
        secondContactTimer = timer('ExecutionMode',  'singleShot'         ...
                                  ,'BusyMode',       'drop'               ...
                                  ,'Name',           ['weight-secondContact-' userInfo.ID]  ...
                                  ,'startDelay',     deadline*60          ...
                                  ,'TasksToExecute', 1                    ...
                                  ,'TimerFcn',       {@reassessContact,userInfo,dataBaseObj,noticeDay}            ...
                                  ,'UserData',       notWeighed           ...
                                  );
        start(secondContactTimer)
      end
     
    end

  %% tech check
  case 'tech'
    notWeighed         = {};
    notWeighed_rsch    = {};
    userInfo_rsch      = {};
    for iResearcher = 1:numel(overview.Researchers)
      if strcmpi(overview.Researchers(iResearcher).TechResponsibility,'no'); continue; end
      
      newmice     = {};
      [logs,mice] = getCurrentlyActiveMouseLogs(userInfo,overview.Researchers(iResearcher).ID,dataBaseObj); 
      if isempty(mice); continue; end
      
      hasNoData   = cellfun(@(x)(isempty(x)),logs,'UniformOutput',false);
      hasNoData   = [hasNoData{:}];
      newmice     = [newmice {mice(hasNoData).ID}]; 
      logs        = logs(~hasNoData);
      mice        = mice(~hasNoData);
      lastEntries = cellfun(@(x)(x(end)),logs);
      todayIs     = floor(now());
      hasEntry    = arrayfun(@(x)(datenum(x.date) == todayIs && (~isempty(x.weight) || ~isempty(strfind(x.weightNotice,'Tech')))),lastEntries);
      newmice     = [newmice {mice(~hasEntry).ID}];
      notWeighed  = [notWeighed newmice];
      
      if ~isempty(newmice)
      	notWeighed_rsch{end+1}   = newmice;
        userInfo_rsch{end+1}     = overview.Researchers(iResearcher);
      end
      
      % write to spreadsheet to prevent other machines from triggering notification
      for iMouse = 1:numel(newmice)
        currNotice = lastEntries(strcmpi({mice(:).ID},newmice{iMouse})).weightNotice;
        newNotice  = sprintf('%s - Tech (%s)',currNotice,userInfo.ID);
        dataBaseObj.pushDailyInfo(overview.Researchers(iResearcher).ID, newmice{iMouse}, 'weightNotice', newNotice);
      end
    end
    
    %% notify tech with all problematic animals
    if ~isempty(notWeighed)
      msg = 'The following animals have not been weighed today: ';
      msg = [msg notWeighed{1}];
      if numel(notWeighed) > 1
        mouseList = cellfun(@(x)([', ' x]),notWeighed(2:end) ,'UniformOutput',false);
        mouseList = [mouseList{:}];
        msg       = [msg mouseList];
      end
    
      msg = sprintf('Hi %s, \n%s.\nPlease resolve this issue before leaving',userInfo.ID,msg);
      send_notification(userInfo,msg,'all');  

      %% notify reserachers with their specific animals
      for iUser = 1:numel(userInfo_rsch)
        whosSecondary      = userInfo_rsch{iUser}.SecondaryContact;
        whosPrimary        = userInfo_rsch{iUser}.ID;
        if ~strcmpi(userInfo_rsch{iUser}.Presence,'Available')
          secondaryContact     = true;
          userInfo_rsch{iUser} = dataBaseObj.findResearcher(whosSecondary);
        else
          secondaryContact     = false;
        end

        msg = sprintf('%s checked out, but the following animals have not been weighed today: ',userInfo.ID);
        msg = [msg notWeighed_rsch{iUser}{1}];
        if numel(notWeighed_rsch{iUser}) > 1
          mouseList = cellfun(@(x)([', ' x]),notWeighed_rsch{iUser}(2:end) ,'UniformOutput',false);
          mouseList = [mouseList{:}];
          msg       = [msg mouseList];
        end

        if secondaryContact
          msg = sprintf('Hi %s, you are receiving this message because you are listed as the secondary contact for %s\n%s.',whosSecondary,whosPrimary,msg);
          send_notification(userInfo_rsch{iUser},msg,'preferred');
        else
          msg = sprintf('Hi %s, \n%s.\n',whosPrimary,msg);
          send_notification(userInfo_rsch{iUser},msg,'preferred');
        end

      end
    end
end

end

%% timer function for new contact
function reassessContact(obj,event,userInfo,dataBaseObj,noticeDay)

stop(obj)
delete(obj)

%% find animals with missing entries 
[logs,mice] = getCurrentlyActiveMouseLogs(userInfo,userInfo.ID);
hasNoData   = cellfun(@(x)(isempty(x)),logs,'UniformOutput',false);
hasNoData   = [hasNoData{:}];
notWeighed  = {mice(hasNoData).ID};
logs        = logs(~hasNoData);
mice        = mice(~hasNoData);
% find entry for the day in question (do not assume it's the last
for iMouse = 1:numel(mice)
  thislog             = logs{iMouse};
  idx                 = arrayfun(@(x)(datenum(x.date) == noticeDay),thislog,'UniformOutput',false);
  lastEntries(iMouse) = thislog([idx{:}]);
end
hasEntry    = arrayfun(@(x)(~isempty(x.weight) || ~isempty(strfind(x.weightNotice,'Secondary'))),lastEntries);
notWeighed  = [notWeighed {mice(~hasEntry).ID}];

%% write to spreadsheet to prevent other machines from triggering notification
for iMouse = 1:numel(notWeighed)
  currNotice = lastEntries(strcmpi({mice(:).ID},notWeighed{iMouse})).weightNotice;
  newNotice  = sprintf('%s - Secondary (%s)',currNotice,userInfo.SecondaryContact);
  dataBaseObj.pushDailyInfo(userInfo.ID, notWeighed{iMouse}, 'weightNotice', newNotice);
end

%% notify
if ~isempty(notWeighed)
  dataBaseObj.pullOverview;
  whosPrimary      = userInfo.ID;
  whosSecondary    = userInfo.SecondaryContact;
  userInfo         = dataBaseObj.findResearcher(whosSecondary);
  
  msg = 'Their following animals have not been weighed today and they have not acted within the deadline: ';
  msg = [msg notWeighed{1}];
  if numel(notWeighed) > 1
    mouseList = cellfun(@(x)([', ' x]),notWeighed(2:end) ,'UniformOutput',false);
    mouseList = [mouseList{:}];
    msg = [msg mouseList];
  end
  msg = sprintf('Hi %s, you are receiving this message because you are listed as the secondary contact for %s\n%s.',whosSecondary,whosPrimary,msg);
  send_notification(userInfo,msg,'all');
        
end
end