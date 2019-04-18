function checkActionItems(userInfo,dataBaseObj)

% checkActionItems(userInfo)
% checks for weight loss over days and if action items were checked
% researcher will be notified for all, tech only for animals for which they
% are directly responsible. If researcher doesn't act within predefined
% deadline, secondary contact gets notified
% userInfo is overview sheet for a specific user, can be either researcher
% or tech

%% get database
if nargin < 2; dataBaseObj = AnimalDatabase; end
dataBaseObj.pullOverview;

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
    [logs,mice]     = getCurrentlyActiveMouseLogs(userInfo,userInfo.ID,dataBaseObj);
    if isempty(mice); return; end
    hasNoData       = cellfun(@(x)(isempty(x)),logs,'UniformOutput',false);
    hasNoData       = [hasNoData{:}];
    logs            = logs(~hasNoData);
    mice            = mice(~hasNoData);
    lastEntries     = cellfun(@(x)(x(end)),logs);
    notified        = arrayfun(@(x)(hasBeenNotified(x)),lastEntries);
    unchecked       = arrayfun(@(x)(findUncheckedActions(x)),lastEntries);
    missingActIdx   = find([unchecked(:).hasUnchecked] & ~notified);
    weightLoss      = isWeightFalling(logs);
    skinnyMice      = {mice(weightLoss & ~notified).ID};
 
    %% decide who to contact
    whosSecondary      = userInfo.SecondaryContact;
    whosPrimary        = userInfo.ID; 
    if ~strcmpi(userInfo.Presence,'Available')
      secondaryContact = true;
      userInfo         = dataBaseObj.findResearcher(whosSecondary);
    else
      secondaryContact = false;
    end
    
    %% write to spreadsheet to prevent other machines from triggering notification
    notifyAbout     = unique([skinnyMice {mice(missingActIdx).ID}]);
    notice          = sprintf('Primary (%s)',userInfo.ID);
    if secondaryContact; notice = [notice '(sub)']; end
    for iMouse = 1:numel(notifyAbout)
      dataBaseObj.pushDailyInfo(userInfo.ID, notifyAbout{iMouse}, 'healthNotice', notice);
    end
    
    %% write and send message about weight loss / missing action items if necessary
    if ~isempty(skinnyMice) || ~isempty(missingActIdx)
      if ~isempty(skinnyMice)
        msg = 'The following animals have abnormally low weight: ';
        msg = [msg skinnyMice{1}];
        if numel(skinnyMice) > 1
          mouseList = cellfun(@(x)([', ' x]), skinnyMice(2:end) ,'UniformOutput',false);
          mouseList = [mouseList{:}];
          msg       = [msg mouseList];
        end
        msg = sprintf('%s\n',msg);
      else
        msg = '';
      end
      
      if ~isempty(missingActIdx)
        msg = sprintf('%s\nThe following animals have unchecked action items:\n',msg);
        for iMouse = 1:numel(missingActIdx)
          msg = sprintf('%s%s: %s',msg,mice(missingActIdx(iMouse)).ID,unchecked(missingActIdx(iMouse)).actionList{1});
          if numel(unchecked(missingActIdx(iMouse)).actionList) > 1
            actionList = cellfun(@(x)([', ' x]), unchecked.(missingActIdx(iMouse)).actionList(2:end) ,'UniformOutput',false);
            msg        = [msg actionList];
          end
          msg = sprintf('%s\n',msg);
        end
      end
      
      if secondaryContact
        msg = sprintf('Hi %s, you are receiving this message because you are listed as the secondary contact for %s, who is away\n%s',whosSecondary,whosPrimary,msg); 
      else
        msg = sprintf('Hi %s, \n%s',whosPrimary,msg);
      end
      
      send_notification(userInfo,msg,'preferred');
      
    end

  case 'tech'
    return
%     warning('NOTIFICATIONS:checkActionItems','Health check notifications are not implemented for techs.')
    
end

end

%% has user already been notified?
function notified = hasBeenNotified(dayLog)

todayIs = floor(now());
if datenum(dayLog.date) == todayIs && strcmpi(dayLog.healthNotice,'Primary') 
  notified = true;
else
  notified = false;
end
              
end

%% list unchecked actions
function unchecked = findUncheckedActions(dayLog)

unchecked.hasUnchecked = false;
unchecked.actionList   = {};
todayIs                = floor(now());
if datenum(dayLog.date) ~= todayIs || isempty(dayLog.actions); return; end

isUnchecked            = [dayLog.actions{:,1}] == YesNoMaybe.No;
unchecked.hasUnchecked = sum(isUnchecked) > 0;
unchecked.actionList   = dayLog.actions(isUnchecked',2);
              
end