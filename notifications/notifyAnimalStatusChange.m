function notifyAnimalStatusChange(animalInfo,researcherOrTech,previousStatus,dataBaseObj)

% notifyAnimalStatusChange(animalInfo,researcherOrTech)
% GUI plugin. notifies animal owner or tech of status change
% animalInfo is info sheet obtained from AnimalDatabase.pullAnimalList()
% researchOrTech is string, 'researcher' if owner must be notified when 
% their animal has been flagged as missing or dead, 'tech' if they need to
% be notified that their flag has been reversed (e.g. animal was found and
% added back to active)

%% defaults
if nargin < 3 || isempty(previousStatus)
  previousStatus = 'missing or dead';
end

%% get database
if nargin < 4; dataBaseObj = AnimalDatabase; end
overview    = dataBaseObj.pullOverview;

%% get new status and owner
newstatus   = char(animalInfo.status{end});
owner       = animalInfo.owner;
mouseID     = animalInfo.ID;

%% notify owner or tech
switch researcherOrTech
  case {'tech','Tech'}
    
    userInfo = overview.Technicians;
    msg      = sprintf('%s has changed %s''s status from %s to %s',owner,mouseID,char(previousStatus),newstatus);
    send_notification(userInfo,msg,'preferred');
    
  case {'researcher','Researcher','owner'}
    
    msg                = sprintf('%s has been flagged as %s',mouseID,newstatus);
    
    % decide who to contact
    userInfo           = dataBaseObj.findResearcher(owner);
    whosSecondary      = userInfo.SecondaryContact;
    whosPrimary        = userInfo.ID; 
    if strcmpi(userInfo.Presence,'Available')
      msg              = sprintf('Hi %s, \n%s',whosPrimary,msg);
    else
      userInfo         = dataBaseObj.findResearcher(whosSecondary);
      msg              = sprintf('Hi %s, you are receiving this message because you are listed as the secondary contact for %s\n%s.',whosSecondary,whosPrimary,msg);
    end
    
    send_notification(userInfo,msg,'all');
    
end

