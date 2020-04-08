function GUI_input = create_GUI_input(obj, parent, field_info)
% Create a corresponding GUI input object for each field input
%
% Inputs:
% obj          = AddRecordsGUI object
% parent       = Parent GUI object for the GUI_input object
% field_info   = structure with information about each field
% tooltip      = string tooltip for the field
%
% Outputs
% GUI_input    = GUI_input object for the field


%Create correspondin GUI_input depending of  gui_type
if strcmp(field_info.gui_type, 'blob')
    %Blob is normally an array of entries
    %So the corresponding GUI_input is a hbox with multiple edits
    GUI_input = GUI_Input_HBox(parent, ...
        field_info.name, ...
        field_info.example_value, ...
        field_info.datatype);
    
elseif strcmp(field_info.gui_type, 'popupmenu')
    %Popumenu is normally for inserting foreign keys inputs
    GUI_input = GUI_Input_Popup(parent, ...
        field_info.name, ...
        field_info.list_values, ...
        field_info.default, ...
        field_info.datatype);
    
else
    %With other inputs a simple edit would be enough
    GUI_input = GUI_Input_Edit(parent, ...
        field_info.name, ...
        field_info.default, ...
        field_info.datatype);
end

end