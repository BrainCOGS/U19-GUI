function notifyVeryLowWeight(animalInfo,dataBaseObj)

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

msg_head            = sprintf('%s''s weight has dropped below 70%% despite supplemental water\nAccording to protocol 1910 animal must be removed from study and euthanized',mouseID);
msg = msg_head;

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

send_notification(userInfo,msg,'all');


%ALS_correct
%Add additional feature (per LAR request): If animal reaches endpoint
%via 1910 protocol. Automatically and immediately send emails to people specified in a list (new dj table).
if animalInfo.protocol == '1910'
    notification_mails = fetchn(lab.EndpointNotification, 'email');
    msg = sprintf('You are receiving this message because you are listed for endpoint notifications:\n%s.',msg_head);
    title =  sprintf('Endpoint notification for animal: %s',mouseID);
    for mail = notification_mails
        send_email(mail, title, msg);
    end
end


