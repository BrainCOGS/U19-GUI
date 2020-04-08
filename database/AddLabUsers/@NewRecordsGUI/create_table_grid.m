function [grid, gui_input_objects] = create_table_grid(obj, parent)
% Create a input Grid for the GUI
%
% Inputs:
% obj                  = AddRecordsGUI object
% parent               = Parent GUI object for the grid
%
% Outputs
% grid                 = GUI object for the grid
% gui_input_objects    = array of objects to recieve input from user


% Get how many inputs the GUI would have
num_inputs = length(obj.GUI_inputs_info);
grid = uix.Grid( 'Parent', parent, 'Spacing', 5 );

%Initialize labels and input objects
field_labels = cell(num_inputs, 1);
gui_input_objects = cell(num_inputs, 1);


%Define labels with name for each field
for i = 1:num_inputs
    field_info = obj.GUI_inputs_info(i);
    field_labels{i} = obj.create_label(grid, ...
        field_info.name, field_info.tooltip);
end

%Define GUI input objects
for i = 1:num_inputs
    field_info = obj.GUI_inputs_info(i);
    gui_input_objects{i} = obj.create_GUI_input(grid, field_info);
end

%Set widths and heights for the grid
grid_widths = -1*ones(NewRecordsGUI.GRID_NUM_COLUMNS,1);
grid_heights = -1*ones(num_inputs,1);
set(grid, 'Widths', grid_widths, 'Heights', grid_heights);

end   
