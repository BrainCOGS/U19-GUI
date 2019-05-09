function vr = notifyUser(vr)


mouse        = vr.protocol.animal.name;
logname      = vr.logger.logFile;
prename      = 'C:\Data\';
postchar     = '\';
logname      = logname(strfind(logname,prename)+numel(prename):end);
firstchar    = strfind(logname,postchar);
firstchar    = firstchar(1);
experimenter = logname(1:firstchar-1);
rwamount     = vr.protocol.totalRewards; 
message      = sprintf('%s is done, received %1.1fmL', mouse, rwamount);

switch experimenter
  case {'lucas','sakoay','edward','ben','Ben'}
    recipients = {'6096940013'};
    carrier    = {'verizon'};
  case 'dbakshinskaya'
    recipients = {'7189137258'};
    carrier    = {'att'};
  case 'sbolkan'
    recipients = {'5039998665'};
    carrier    = {'att'};
end

send_msg(recipients, [], message, carrier)