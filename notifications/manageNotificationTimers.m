function manageNotificationTimers(action,dataBaseObj)

% manageNotificationTimers(action)
% manages all timers related to user notifications, according to input
% action:
% 'stop': stops and deletes all existing timer objects running in the background
% 'check': check if timers are running, warns otherwise and restarts idle timers
% 'start': will call notificationTimer
% 'reset': stops then calls notificationTimer

switch action
  case 'start'
    notificationTimer(dataBaseObj);
    
  case 'stop'   
    timerList = {'databaseUpdate','weeklyDigest','nextDailyCheck'};
    for iTimer = 1:numel(timerList)
      thistimer = timerfind('Name',timerList{iTimer});
      if isempty(thistimer); continue; end
      
       stop(thistimer);
       delete(thistimer);
       clear thistimer
    end
    
  case 'reset'
    manageNotificationTimers('stop');
    notificationTimer(dataBaseObj);
    
  case 'check'   
    timerObjs = timerfindall;
    if isempty(timerObjs);
      warning('NOTIFICATIONS:manageNotificationTimers', 'No timers found.');
      return
    end

    for iTimer = 1:numel(timerObjs)
      if  strcmpi(timerObjs(iTimer).Name,'databaseUpdate') || ...
          strcmpi(timerObjs(iTimer).Name,'weeklyDigest')   || ...
          strcmpi(timerObjs(iTimer).Name,'nextDailyCheck') 
          
          
        if ~isvalid(timerObjs(iTimer))
          warning('NOTIFICATIONS:manageNotificationTimers', '%s timer is invalid. Resetting.',timerObjs(iTimer).Name);
          notificationTimer(dataBaseObj);
        elseif ~strcmpi(get(timerObjs(iTimer),'Running'), 'on')
          warning('NOTIFICATIONS:manageNotificationTimers', '%s timer seems to have stopped. Resetting.',timerObjs(iTimer).Name);
          notificationTimer(dataBaseObj);
        end
      
      elseif ~isempty(strfind(timerObjs(iTimer).Name,'secondContact'))
        
        if ~strcmpi(get(timerObjs(iTimer),'Running'), 'on')
          warning('NOTIFICATIONS:manageNotificationTimers', '%s timer seems to have stopped. Resetting.',timerObjs(iTimer).Name);
          start(timerObjs(iTimer))
        end

      end
    end
    
end