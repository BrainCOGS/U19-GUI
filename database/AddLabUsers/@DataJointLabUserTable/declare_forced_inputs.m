function forced_inputs = declare_forced_inputs(obj)
% Define which values are forced to have an input (can't be
% empty)
%
%create obj.GUI_inputs_info.forced_input field
%

forced_inputs = cell(length(obj.GUI_info),1);
%For each field of the record
for i=1:length(obj.GUI_info)
    %Check if there is a FORCED_DEFAULT for it
    if any(contains(DataJointLabUserTable.FORCED_INPUT, obj.GUI_info(i).name))
        %Override default from database
        forced_inputs{i} = true;
    else
        forced_inputs{i} = false;
    end
    
end
end