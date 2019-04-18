function checkCageReturn(userInfo,dataBaseObj)

% checkCageReturn(userInfo)
% checks if mouse has been returned to vivarium
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
    
    %% find animals not in vivarium
    [logs, mice]    = getCurrentlyActiveMouseLogs(userInfo,userInfo.ID,dataBaseObj);
    if isempty(mice); return; end
    lastEntries     = cellfun(@(x)(x(end)),logs);
    todayIs         = floor(now());
    isInVivarium    = arrayfun(@(x)(strcmpi(x.whereAmI,'vivarium')),mice) | ...
                      arrayfun(@(x)(datenum(x.date) == todayIs),lastEntries);
    wasNotified     = arrayfun(@(x)(~isempty(strfind(x.cageNotice,'Primary'))),lastEntries);
    notReturned     = {mice(~isInVivarium & ~wasNotified).ID};
    mouseIDs        = {mice(:).ID};
    cageIDs         = {mice(:).cage};
    missingCages    = unique(cageIDs(ismember(upper(mouseIDs),upper(notReturned))));

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
    for iMouse = 1:numel(notReturned)
      currNotice = lastEntries(strcmpi(mouseIDs,notReturned{iMouse})).cageNotice;
      newNotice  = sprintf('%s - Primary (%s)',currNotice,userInfo.ID);
      if secondaryContact; newNotice = [newNotice '(sub)']; end
      dataBaseObj.pushDailyInfo(whosPrimary, notReturned{iMouse}, 'cageNotice', newNotice);
    end
    
    %% write and send message about missing cages, and start timer if primary user
    if ~isempty(notReturned)
      msg = 'The following animals have not been returned to the vivarium today: ';
      msg = [msg notReturned{1}];
      if numel(notReturned) > 1
        mouseList = cellfun(@(x)([', ' x]),notReturned(2:end) ,'UniformOutput',false);
        mouseList = [mouseList{:}];
        msg       = [msg mouseList];
      end
      msg = sprintf('%s\nThey belong to the following cages: ',msg);
      msg = [msg missingCages{1}];
      if numel(missingCages) > 1
        cageList  = cellfun(@(x)([', ' x]),missingCages(2:end) ,'UniformOutput',false);
        cageList  = [cageList{:}];
        msg       = [msg cageList];
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
                                  ,'Name',           ['cage-secondContact-' userInfo.ID]  ...
                                  ,'startDelay',     deadline*60          ...
                                  ,'TasksToExecute', 1                    ...
                                  ,'TimerFcn',       {@reassessContact,userInfo,dataBaseObj,noticeDay}          ...
                                  ,'UserData',       notReturned          ...
                                  );
        start(secondContactTimer)
      end
    end

  %% tech check (only cages they had/were responsible for)
  case 'tech'
    dataBaseObj        = AnimalDatabase;
    overview           = dataBaseObj.pullOverview;
    notReturned        = {};
    missingCages       = {};
    notReturned_rsch   = {};
    missingCages_rsch  = {};
    userInfo_rsch      = {};
    for iResearcher = 1:numel(overview.Researchers)
      if strcmpi(overview.Researchers(iResearcher).TechResponsibility,'no'); continue; end
      
      [logs, mice]    = getCurrentlyActiveMouseLogs(userInfo,overview.Researchers(iResearcher).ID,dataBaseObj);
      if isempty(mice); continue; end
      
      lastEntries     = cellfun(@(x)(x(end)),logs);
      todayIs         = floor(now());
      isInVivarium    = arrayfun(@(x)(strcmpi(x.whereAmI,'vivarium')),mice);
      isWithTech      = arrayfun(@(x)(strcmpi(x.whereAmI,userInfo.ID)),mice) | ...
                        arrayfun(@(x)(datenum(x.date) == todayIs),lastEntries);
      wasNotified     = arrayfun(@(x)(~isempty(strfind(x.cageNotice,'Tech'))),lastEntries);
      newmice         = {mice(~isInVivarium & isWithTech & ~wasNotified).ID};
      notReturned     = [notReturned newmice];
      mouseIDs        = {mice(:).ID};
      cageIDs         = {mice(:).cage};
      newcages        = unique(cageIDs(ismember(upper(mouseIDs),upper(notReturned))));
      missingCages    = [missingCages newcages];
      
      if ~isempty(newmice)
        notReturned_rsch{end+1}   = newmice;
        missingCages_rsch{end+1}  = newcages;
        userInfo_rsch{end+1}      = overview.Researchers(iResearcher);
        
        % write to spreadsheet to prevent other machines from triggering notification
        for iMouse = 1:numel(newmice)
          currNotice = lastEntries(strcmpi({mice(:).ID},newmice{iMouse})).cageNotice;
          newNotice  = sprintf('%s - Tech (%s)',currNotice,userInfo.ID);
          dataBaseObj.pushDailyInfo(overview.Researchers(iResearcher).ID, newmice{iMouse}, 'cageNotice', newNotice);
        end
      end
    end
    
    %% notify tech with all animals
    if ~isempty(notReturned)
      msg = 'The following animals have not been returned to the vivarium today: ';
      msg = [msg notReturned{1}];
      if numel(notReturned) > 1
        mouseList = cellfun(@(x)([', ' x]),notReturned(2:end) ,'UniformOutput',false);
        mouseList = [mouseList{:}];
        msg       = [msg mouseList];
      end
      msg = sprintf('%s\nThey belong to the following cages: ',msg);
      msg = [msg missingCages{1}];
      if numel(missingCages) > 1
        cageList  = cellfun(@(x)([', ' x]),missingCages(2:end) ,'UniformOutput',false);
        cageList  = [cageList{:}];
        msg       = [msg cageList];
      end
    
      msg = sprintf('Hi %s, \n%s.\nPlease resolve this issue before leaving',userInfo.ID,msg);
      send_notification(userInfo,msg,'all');  

      %% notify researchers with specific animals
      for iUser = 1:numel(userInfo_rsch)
        whosSecondary      = userInfo_rsch{iUser}.SecondaryContact;
        whosPrimary        = userInfo_rsch{iUser}.ID;
        if ~strcmpi(userInfo_rsch{iUser}.Presence,'Available')
          secondaryContact     = true;
          userInfo_rsch{iUser} = dataBaseObj.findResearcher(whosSecondary);
        else
          secondaryContact     = false;
        end

        msg = sprintf('%s checked out, but the following animals have not been returned to the vivarium today: ',userInfo.ID);
        msg = [msg notReturned_rsch{iUser}{1}];
        if numel(notReturned_rsch{iUser}) > 1
          mouseList = cellfun(@(x)([', ' x]),notReturned_rsch{iUser}(2:end) ,'UniformOutput',false);
          mouseList = [mouseList{:}];
          msg       = [msg mouseList];
        end
        msg = sprintf('%s\nThey belong to the following cages: ',msg);
        msg = [msg missingCages_rsch{iUser}{1}];
        if numel(missingCages) > 1
          cageList  = cellfun(@(x)([', ' x]),missingCages_rsch{iUser}(2:end) ,'UniformOutput',false);
          cageList  = [cageList{:}];
          msg       = [msg cageList];
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

[logs, mice]    = getCurrentlyActiveMouseLogs(userInfo,userInfo.ID,dataBaseObj);
if isempty(mice); return; end
% find entry for the day in question (do not assume it's the last
for iMouse = 1:numel(mice)
  thislog             = logs{iMouse};
  idx                 = arrayfun(@(x)(datenum(x.date) == noticeDay),thislog,'UniformOutput',false);
  lastEntries(iMouse) = thislog([idx{:}]);
end
isInVivarium    = arrayfun(@(x)(strcmpi(x.whereAmI,'vivarium')),mice);
wasNotified     = arrayfun(@(x)(~isempty(strfind(x.cageNotice,'Secondary'))),lastEntries);
notReturned     = {mice(~isInVivarium & ~wasNotified).ID};
mouseIDs        = {mice(:).ID};
cageIDs         = {mice(:).cage};
missingCages    = unique(cageIDs(ismember(upper(mouseIDs),upper(notReturned))));

%% write to spreadsheet to prevent other machines from triggering notification
for iMouse = 1:numel(notReturned)
  currNotice = lastEntries(strcmpi(mouseIDs,notReturned{iMouse})).cageNotice;
  newNotice  = sprintf('%s - Secondary (%s)',currNotice,userInfo.SecondaryContact);
  dataBaseObj.pushDailyInfo(userInfo.ID, notReturned{iMouse}, 'cageNotice', newNotice);
end

%% notify
if ~isempty(notReturned)
  dataBaseObj.pullOverview;
  whosPrimary      = userInfo.ID;
  whosSecondary    = userInfo.SecondaryContact;
  userInfo         = dataBaseObj.findResearcher(whosSecondary);
  
  msg = 'The following animals have not been returned to the vivarium today: ';
  msg = [msg notReturned{1}];
  if numel(notReturned) > 1
    mouseList = cellfun(@(x)([', ' x]),notReturned(2:end) ,'UniformOutput',false);
    mouseList = [mouseList{:}];
    msg       = [msg mouseList];
  end
  msg = sprintf('%s\nThey belong to the following cages: ',msg);
  msg = [msg missingCages{1}];
  if numel(missingCages) > 1
    cageList  = cellfun(@(x)([', ' x]),missingCages(2:end) ,'UniformOutput',false);
    cageList  = [cageList{:}];
    msg       = [msg cageList];
  end
      
  msg = sprintf('Hi %s, you are receiving this message because you are listed as the secondary contact for %s\n%s.',whosSecondary,whosPrimary,msg);
  send_notification(userInfo,msg,'all');
        
end
    
end