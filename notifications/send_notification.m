function send_notification(userInfo,message,notificationMethod,msgtitle)

% send_notification(userInfo,message,notificationMethod)
% notifies users using the method in 
%       notificationMethod: 'text','email','slack','all' (or 'emergency'),
%                           'preferred' (default, set in userInfo.ContactVia)
%
% userInfo is a data structure obtained from the BRAIN mouse database, from
% the general user info spreadsheet. Get it with TrainingDatabase.pullOverview
%
% message is a string with the message to be sent (if the same for all users)
% or a cell array for user-specific messages

%% default is preferred method set in userInfo.ContactVia
if nargin < 3
  notificationMethod = 'preferred';
end
if nargin < 4
  msgtitle           = 'BRAIN Rig notification';
end

%% make it into cell because userInfo could be made of dissimilar structures
% in some cases (e.g. researchers vs. techs)
% message should also be turned into cell for flexibility
if ~iscell(userInfo)
  temp = userInfo; clear userInfo;
  for iUser = 1:numel(temp)
    userInfo{iUser} = temp(iUser);
  end
end
if ~iscell(message) || (iscell(message) && numel(message)==1)
  nUsers   = numel(userInfo);
  message  = repmat({message},[1 nUsers]);
end
if ~iscell(msgtitle) || (iscell(msgtitle) && numel(msgtitle)==1)
  nUsers   = numel(userInfo);
  msgtitle = repmat({msgtitle},[1 nUsers]);
end
%% send message to users
switch notificationMethod
  case 'text'
    
    for iUser = 1:numel(userInfo)
      send_msg({userInfo{iUser}.Phone}, [], message{iUser}, {userInfo{iUser}.Carrier});
    end
    
  case 'email'
    
    for iUser = 1:numel(userInfo)
      send_email({userInfo{iUser}.Email}, msgtitle{iUser}, message{iUser});
    end
    
  case 'slack'
    
    for iUser = 1:numel(userInfo)
      %ALS_correct SlackNotification Not working
      %SendSlackNotification(userInfo{iUser}.slackWebhook, message{iUser});
    end
    
  case {'all','emergency'}
    
    for iUser = 1:numel(userInfo)
      send_email({userInfo{iUser}.Email}, msgtitle{iUser}, message{iUser});
      %ALS_correct SlackNotification Not working
      %SendSlackNotification(userInfo{iUser}.slackWebhook, message{iUser});
      send_msg({userInfo{iUser}.Phone}, [], message{iUser}, {userInfo{iUser}.Carrier});
    end
    
  case 'preferred'
    
    for iUser = 1:numel(userInfo)
      
      % figure out which are the preferred methods (there can be more than
      % one)
      pref    = userInfo{iUser}.ContactVia;
      methods = {};
      if ~isempty(strfind(pref,'ext'));  methods{end+1} = 'text';  end
      if ~isempty(strfind(pref,'lack')); methods{end+1} = 'slack'; end
      if ~isempty(strfind(pref,'mail')); methods{end+1} = 'email'; end
      
      for iMethod = 1:numel(methods);
        switch methods{iMethod}
          case 'slack'
            %ALS_correct SlackNotification Not working  
            %SendSlackNotification(userInfo{iUser}.slackWebhook, message{iUser});
            
          case 'text'
            send_msg({userInfo{iUser}.Phone}, [], message{iUser}, {userInfo{iUser}.Carrier});
            
          case 'email'
            send_email({userInfo{iUser}.Email}, msgtitle{iUser}, message{iUser});
        end
      end
    end
end
