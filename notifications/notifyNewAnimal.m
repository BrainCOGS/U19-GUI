function notifyNewAnimal(animalInfo,dataBaseObj)

% notifyNewAnimal(animalInfo)
% GUI plugin. notifies tech if new animal has been added to water
% restriction
% animalInfo is info sheet obtained from AnimalDatabase.pullAnimalList()

%% get database
if nargin < 2; dataBaseObj = AnimalDatabase; end
overview    = dataBaseObj.pullOverview;

%% get new status and owner
owner          = animalInfo.owner;
mouseID        = animalInfo.ID;
techs          = overview.Technicians;
primaryTech    = techs(strcmpi({techs(:).primaryTech},'yes')).ID;
techIsNotified = dataBaseObj.shouldICare(animalInfo,primaryTech,true);

if techIsNotified
 
  msg = sprintf('You have a new furry friend! New animal %s has been added to water restriction by %s', ...
                mouseID,owner);
  send_notification(techs,msg,'preferred');
  
end
