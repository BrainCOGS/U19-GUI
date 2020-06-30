function forced_defaults = declare_forced_defaults(obj)
% Define some defaults to fields
%
%some obj.GUI_inputs_info.default values are overriden with known values
%

forced_defaults = cell(length(obj.GUI_info),1);
%For each field of the record
for i=1:length(obj.GUI_info)
    %Check if there is a FORCED_DEFAULT for it
    if isfield(DataJointLabUserTable.FORCED_DEFAULT, obj.GUI_info(i).name)
        %Override default from database
        forced_defaults{i} = ...
            DataJointLabUserTable.FORCED_DEFAULT.(obj.GUI_info(i).name);
    else
        forced_defaults{i} = '';
    end
    
end
end

