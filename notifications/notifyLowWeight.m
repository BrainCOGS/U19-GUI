function notifyLowWeight(animalInfo,dataBaseObj)

% notifyLowWeight(animalInfo)
% GUI plugin. notifies animal owner if weight has dropped below 80%, after tech has
% attempted giving supplemental water and failed
% animalInfo is info sheet obtained from AnimalDatabase.pullAnimalList()

%% get database
if nargin < 2; dataBaseObj = AnimalDatabase; end
dataBaseObj.pullOverview;

%% get new status and owner
owner          = animalInfo.owner;
mouseID        = animalInfo.ID;

%% notify owner (or secondary contact)

msg            = sprintf('%s''s weight has dropped below 80%% despite supplemental water',mouseID);

% decide who to contact
userInfo       = dataBaseObj.findResearcher(owner);
whosSecondary  = userInfo.SecondaryContact;
whosPrimary    = userInfo.ID;
if strcmpi(userInfo.Presence,'Available')
 msg           = sprintf('Hi %s, \n%s',whosPrimary,msg);
else
 userInfo      = dataBaseObj.findResearcher(whosSecondary);
 msg           = sprintf('Hi %s, you are receiving this message because you are listed as the secondary contact for %s\n%s.',whosSecondary,whosPrimary,msg);
end

send_notification(userInfo,msg,'preferred');