function send_email(recipients, subject, message)

if ~iscell(recipients); recipients = {recipients}; end

% =========================================================
% YOU NEED TO TYPE IN YOUR OWN EMAIL AND PASSWORDS:
mail = 'vrrigs.bi.pni@gmail.com';  %Your GMail email address
pwd  = 'ofMice&Towers';            %Your GMail password
% =========================================================

% Then this code will set up the preferences properly:
setpref('Internet','E_mail',mail);
setpref('Internet','SMTP_Server','smtp.gmail.com');
setpref('Internet','SMTP_Username',mail);
setpref('Internet','SMTP_Password',pwd);

% The following four lines are necessary only if you are using GMail as
% your SMTP server. Delete these lines if you are using your own SMTP
% server.
props = java.lang.System.getProperties;
props.setProperty('mail.smtp.auth','true');
props.setProperty('mail.smtp.socketFactory.class', 'javax.net.ssl.SSLSocketFactory');
props.setProperty('mail.smtp.socketFactory.port','465');

%% Send the email
% Send the email
sendmail(recipients,subject,message);