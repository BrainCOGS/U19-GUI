function create_gui(obj)
%Define all graphic objects for the AddRecordsGUI
%
% Inputs:
% obj = AddRecordsGUI object


%% Define a figure
obj.figGUI = figure( ...
    'Name'            , obj.GUI_NAME,  ...
    'ToolBar'         , 'none',                      ...
    'MenuBar'         , 'none',                      ...
    'NumberTitle'     , 'off',                       ...
    'Visible'         , 'off',                       ...
    'Tag'             , 'persist',                   ...
    'CloseRequestFcn' , @obj.close_figure           ...
    );
% Define figure position and size
figure_position = obj.define_figure_position(NewRecordsGUI.GUI_POSITION);
set(obj.figGUI, NewRecordsGUI.GUI_POSITION_MODE, figure_position)
    

%% Define a panel
obj.panel = uix.Panel( ...
    'Parent', obj.figGUI, ...
    'Padding', 5 );


%% Define the vbox to separate the GUI in three (title, inputs and buttons)
obj.vbox = uix.VBox( ...
    'Parent', obj.panel, ...
    'Spacing', obj.VBOX_SPACING);


%% Define the title
obj.title = obj.create_title(obj.vbox, obj.TITLE_MESSAGE);


%% Define the grid GUI input
[obj.grid, obj.GUI_inputs] = obj.create_table_grid(obj.vbox);


%% Define an hbox to insert the buttons of the GUI
obj.hbox = uix.HBox( ...
    'Parent', obj.vbox, ...
    'Spacing', obj.HBOX_SPACING);


%% All space not used by buttons will be occupied by an empty object
uix.Empty( 'Parent', obj.hbox );


%% Create all buttons for the GUI
obj.button = obj.create_buttons(obj.hbox);


%% Adjust width and height for hbox and vbox
set(obj.hbox, 'Widths', obj.HBOX_WIDTHS);
set(obj.vbox, 'Heights', obj.VBOX_HEIGHTS);
set(obj.figGUI, 'Visible', 'on');

end