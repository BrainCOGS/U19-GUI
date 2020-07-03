function forced_format = declare_forced_format(obj)
% Define some regex to fields, 
% When insertion/updating inputs have to math regex pattern
%
%some obj.GUI_inputs_info.forced_format values are overriden with known values
%

forced_format = cell(length(obj.GUI_info),1);
%For each field of the record
for i=1:length(obj.GUI_info)
    %Check if there is a FORCED_DEFAULT for it
    if isfield(DataJointLabUserTable.FORCED_FORMAT, obj.GUI_info(i).name)
        %Override default from database
        forced_format{i} = ...
            DataJointLabUserTable.FORCED_FORMAT.(obj.GUI_info(i).name);
    else
        forced_format{i} = '';
    end
    
end

