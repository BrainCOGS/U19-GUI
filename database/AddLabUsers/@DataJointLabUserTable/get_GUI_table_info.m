function [GUI_info, tables_update] = get_GUI_table_info(obj)
% Function that defines two structures with information about tables that
% will be updated
% correct
% Inputs:
% obj             = DataJointLabUserTable object
%
% Outputs
% GUI_info        = structure with information for each field of the tables
%                   that will update for defining the GUI
% tables_update   = reference for all the tables that will be updated

GUI_info = struct();

%Create GUI_info structure with information for all fields
GUI_info.name                = 'user_id';
GUI_info.gui_type            = 'edit';
GUI_info.datatype            = 'string';
GUI_info.default             = '';
GUI_info.list_values         = {};
GUI_info.example_value       = '';
GUI_info.tooltip             = 'username';
GUI_info.format              = '^[a-zA-Z0-9]+([.]?[a-zA-Z0-9]+)*$';
GUI_info.formaterr           = ['Only allowed alphanumeric and ''.'' charcaters', ...
                                 newline 'Field cannot start, end or have double ''.'''];

f.name                = 'user_nickname';
f.gui_type            = 'edit';
f.datatype            = 'string';
f.default             = '';
f.list_values         = {};
f.example_value       = '';
f.tooltip             = 'same as netID for new users, for old users, this is used in the folder name etc';
f.format              = '^[a-zA-Z0-9]+([.]?[a-zA-Z0-9]+)*$';
f.formaterr           = ['Only allowed alphanumeric and ''.'' charcaters', ...
                                 newline 'Field cannot start, end or have double ''.'''];
GUI_info = [GUI_info, f];

f.name                = 'full_name';
f.gui_type            = 'edit';
f.datatype            = 'string';
f.default             = '';
f.list_values         = {};
f.example_value       = '';
f.tooltip             = 'first name';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name                = 'email';
f.gui_type            = 'edit';
f.datatype            = 'string';
f.default             = '';
f.list_values         = {};
f.example_value       = '';
f.tooltip             = 'email address';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name                = 'phone';
f.gui_type            = 'edit';
f.datatype            = 'string';
f.default             = '';
f.list_values         = {};
f.example_value       = '';
f.tooltip             = 'phone number';
f.format              = '^[0-9]{10,12}$';
f.formaterr           = 'Only 10 to 12 digits allowed';
GUI_info = [GUI_info, f];

f.name                = 'mobile_carrier';
f.gui_type            = 'popupmenu';
f.datatype            = 'string';
f.default             = '';
f.list_values         = obj.get_values_table_field(lab.MobileCarrier(), 'mobile_carrier');
f.example_value       = '';
f.tooltip             = 'allowed mobile carrier';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name                = 'slack';
f.gui_type            = 'edit';
f.datatype            = 'string';
f.default             = '';
f.list_values         = {};
f.example_value       = '';
f.tooltip             = 'slack username';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name                = 'contact_via';
f.gui_type            = 'popupmenu';
f.datatype            = 'string';
f.default             = 'email';
f.list_values         = {'Slack','text','Email'};
f.example_value       = '';
f.tooltip             = 'Preferred method of contact';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name                = 'presence';
f.gui_type            = 'popupmenu';
f.datatype            = 'string';
f.default             = '';
f.list_values         = {'Available','Away'};
f.example_value       = '';
f.tooltip             = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name               = 'primary_tech';
f.gui_type           = 'popupmenu';
f.datatype           = 'string';
f.default            = 'N/A';
f.list_values        = {'yes','no','N/A'};
f.example_value      = '';
f.tooltip            = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name               = 'tech_responsibility';
f.gui_type           = 'popupmenu';
f.datatype           = 'string';
f.default            = 'yes';
f.list_values        = {'yes','no','N/A'};
f.example_value      = '';
f.tooltip            = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name               = 'day_cutoff_time';
f.gui_type           = 'blob';
f.datatype           = 'numeric array';
f.default            = [16 30];
f.list_values        = {};
f.example_value      = obj.get_values_table_field(lab.User(), 'day_cutoff_time', 'LIMIT 1');
f.tooltip            = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name               = 'slack_webhook';
f.gui_type           = 'edit';
f.datatype           = 'string';
f.default            = '';
f.list_values        = {};
f.example_value      = '';
f.tooltip            = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name               = 'watering_logs';
f.gui_type           = 'edit';
f.datatype           = 'string';
f.default            = '';
f.list_values        = {};
f.example_value      = '';
f.tooltip            = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name                = 'lab';
f.gui_type            = 'popupmenu';
f.datatype            = 'string';
f.default             = '';
f.list_values         = obj.get_values_table_field(lab.Lab(), 'lab');
f.example_value       = '';
f.tooltip             = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name                = 'secondary_contact';
f.gui_type            = 'popupmenu';
f.datatype            = 'string';
f.default             = '';
f.list_values         = obj.get_values_table_field(lab.User(), 'user_id');
f.example_value       = '';
f.tooltip             = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name                = 'project';
f.gui_type            = 'popupmenu';
f.datatype            = 'string';
f.default             = '';
f.list_values         = obj.get_values_table_field(lab.Project(), 'project');
f.example_value       = '';
f.tooltip             = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];

f.name                = 'protocol';
f.gui_type            = 'popupmenu';
f.datatype            = 'string';
f.default             = '';
f.list_values         = obj.get_values_table_field(lab.Protocol(), 'protocol');
f.example_value       = '';
f.tooltip             = '';
f.format              = '';
f.formaterr           = '';
GUI_info = [GUI_info, f];


%Create tables_update structure with references for all tables
tables_update(1).table = lab.User();
tables_update(2).table = lab.UserLab();
tables_update(3).table = lab.UserSecondaryContact();
tables_update(4).table = lab.ProjectUser();
tables_update(5).table = lab.UserProtocol();

for i=1:length(tables_update)
    tables_update(i).fields = tables_update(i).table.header.names;
end

end

