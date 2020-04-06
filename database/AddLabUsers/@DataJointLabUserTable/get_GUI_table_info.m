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


%Create GUI_info structure with information for all fields
GUI_info(1).name                = 'user_id';
GUI_info(1).gui_type            = 'edit';
GUI_info(1).datatype            = 'string';
GUI_info(1).default             = '';
GUI_info(1).list_values         = {};
GUI_info(1).example_value       = '';
GUI_info(1).tooltip             = 'username';

GUI_info(2).name                = 'user_nickname';
GUI_info(2).gui_type            = 'edit';
GUI_info(2).datatype            = 'string';
GUI_info(2).default             = '';
GUI_info(2).list_values         = {};
GUI_info(2).example_value       = '';
GUI_info(2).tooltip             = 'same as netID for new users, for old users, this is used in the folder name etc';

GUI_info(3).name                = 'full_name';
GUI_info(3).gui_type            = 'edit';
GUI_info(3).datatype            = 'string';
GUI_info(3).default             = '';
GUI_info(3).list_values         = {};
GUI_info(3).example_value       = '';
GUI_info(3).tooltip             = 'first name';

GUI_info(4).name                = 'email';
GUI_info(4).gui_type            = 'edit';
GUI_info(4).datatype            = 'string';
GUI_info(4).default             = '';
GUI_info(4).list_values         = {};
GUI_info(4).example_value       = '';
GUI_info(4).tooltip             = 'email address';

GUI_info(5).name                = 'phone';
GUI_info(5).gui_type            = 'edit';
GUI_info(5).datatype            = 'string';
GUI_info(5).default             = '';
GUI_info(5).list_values         = {};
GUI_info(5).example_value       = '';
GUI_info(5).tooltip             = 'phone number';

GUI_info(6).name                = 'mobile_carrier';
GUI_info(6).gui_type            = 'popupmenu';
GUI_info(6).datatype            = 'string';
GUI_info(6).default             = '';
GUI_info(6).list_values         = obj.get_values_table_field(lab.MobileCarrier(), 'mobile_carrier');
GUI_info(6).example_value       = '';
GUI_info(6).tooltip             = 'allowed mobile carrier';

GUI_info(7).name                = 'slack';
GUI_info(7).gui_type            = 'edit';
GUI_info(7).datatype            = 'string';
GUI_info(7).default             = '';
GUI_info(7).list_values         = {};
GUI_info(7).example_value       = '';
GUI_info(7).tooltip             = 'slack username';

GUI_info(8).name                = 'contact_via';
GUI_info(8).gui_type            = 'popupmenu';
GUI_info(8).datatype            = 'string';
GUI_info(8).default             = '';
GUI_info(8).list_values         = {'Slack','text','Email'};
GUI_info(8).example_value       = '';
GUI_info(8).tooltip             = 'Preferred method of contact';

GUI_info(9).name                = 'presence';
GUI_info(9).gui_type            = 'popupmenu';
GUI_info(9).datatype            = 'string';
GUI_info(9).default             = '';
GUI_info(9).list_values         = {'Available','Away'};
GUI_info(9).example_value       = '';
GUI_info(9).tooltip             = '';

GUI_info(10).name               = 'primary_tech';
GUI_info(10).gui_type           = 'popupmenu';
GUI_info(10).datatype           = 'string';
GUI_info(10).default            = 'N/A';
GUI_info(10).list_values        = {'yes','no','N/A'};
GUI_info(10).example_value      = '';
GUI_info(10).tooltip            = '';

GUI_info(11).name               = 'tech_responsibility';
GUI_info(11).gui_type           = 'popupmenu';
GUI_info(11).datatype           = 'string';
GUI_info(11).default            = 'N/A';
GUI_info(11).list_values        = {'yes','no','N/A'};
GUI_info(11).example_value      = '';
GUI_info(11).tooltip            = '';

GUI_info(12).name               = 'day_cutoff_time';
GUI_info(12).gui_type           = 'blob';
GUI_info(12).datatype           = 'numeric array';
GUI_info(12).default            = '';
GUI_info(12).list_values        = {};
GUI_info(12).example_value      = obj.get_values_table_field(lab.User(), 'day_cutoff_time', 'LIMIT 1');
GUI_info(12).tooltip            = '';

GUI_info(13).name               = 'slack_webhook';
GUI_info(13).gui_type           = 'edit';
GUI_info(13).datatype           = 'string';
GUI_info(13).default            = '';
GUI_info(13).list_values        = {};
GUI_info(13).example_value      = '';
GUI_info(13).tooltip            = '';

GUI_info(14).name               = 'watering_logs';
GUI_info(14).gui_type           = 'edit';
GUI_info(14).datatype           = 'string';
GUI_info(14).default            = '';
GUI_info(14).list_values        = {};
GUI_info(14).example_value      = '';
GUI_info(14).tooltip            = '';

GUI_info(15).name                = 'lab';
GUI_info(15).gui_type            = 'popupmenu';
GUI_info(15).datatype            = 'string';
GUI_info(15).default             = '';
GUI_info(15).list_values         = obj.get_values_table_field(lab.Lab(), 'lab');
GUI_info(15).example_value       = '';
GUI_info(15).tooltip             = '';

GUI_info(16).name                = 'secondary_contact';
GUI_info(16).gui_type            = 'popupmenu';
GUI_info(16).datatype            = 'string';
GUI_info(16).default             = '';
GUI_info(16).list_values         = obj.get_values_table_field(lab.User(), 'user_id');
GUI_info(16).example_value       = '';
GUI_info(16).tooltip             = '';

GUI_info(17).name                = 'project';
GUI_info(17).gui_type            = 'popupmenu';
GUI_info(17).datatype            = 'string';
GUI_info(17).default             = '';
GUI_info(17).list_values         = obj.get_values_table_field(lab.Project(), 'project');
GUI_info(17).example_value       = '';
GUI_info(17).tooltip             = '';

GUI_info(18).name                = 'protocol';
GUI_info(18).gui_type            = 'popupmenu';
GUI_info(18).datatype            = 'string';
GUI_info(18).default             = '';
GUI_info(18).list_values         = obj.get_values_table_field(lab.Protocol(), 'protocol');
GUI_info(18).example_value       = '';
GUI_info(18).tooltip             = '';


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

