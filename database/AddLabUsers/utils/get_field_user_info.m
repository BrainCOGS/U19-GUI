function [field_user_info] = get_field_user_info(obj)
%field_user_info 
% Table with some preknown data of some fields
% Each table will consist of three fields: 
% field   = field name
% default = known default value for field
% format  = known regex format to match in input for field

%Outputs
% field_user_info = table with all field info

fieldsInfoFields = {'name', 'default', 'format'};
info = cell2table(cell(0,length(fieldsInfoFields)), ...
    'VariableNames', fieldsInfoFields);

%Define values for each field
s.name = 'contact_via';
s.default = 'email';
s.format = '';
info = [info; struct2table(s,'AsArray',true)];

s.name = 'primary_tech';
s.default = 'N/A';
s.format = '';
info = [info; struct2table(s,'AsArray',true)];

s.name = 'tech_responsibility';
s.default = 'yes';
s.format = '';
info = [info; struct2table(s,'AsArray',true)];

s.name = 'day_cutoff_time';
s.default = [16 30];
s.format = '';
info = [info; struct2table(s,'AsArray',true)];

s.name = 'user_id';
s.default = '';
s.format = '^[a-zA-Z0-9]+([._]?[a-zA-Z0-9]+)*$';
info = [info; struct2table(s,'AsArray',true)];

s.name = 'user_nickname';
s.default = '';
s.format = '^[a-zA-Z0-9]+([._]?[a-zA-Z0-9]+)*$';
info = [info; struct2table(s,'AsArray',true)];

s.name = 'phone';
s.default = '';
s.format = '^[0-9]{10,12}$';
info = [info; struct2table(s,'AsArray',true)];

field_user_info = info;

end

