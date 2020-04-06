classdef NewRecordsGUI < handle
    % NewRecordsGUI   Summary of NewRecordsGUI
    % Define a simple GUI for adding records to a table
    % Table and fields info is defined and a GUI is created with
    % correspondent inputs
    % (Edits, Popupmenu and HBox inputs depending of fields in database)
    %
    % NewRecordsGUI main Properties:
    %    DatabaseTable   - Reference to the tables to add records
    %    GUI_inputs_info - Information of each input of the GUI 
    %    figGUI          - main figure of the GUI
    %    panel           - main panel of the GUI
    %    vbox            - box to separate in three the GUI
    %    (title/input grid/button box)
    %    title           - title part of the GUI
    %    grid            - Grid input part of the GUI
    %    GUI_inputs      - Individual inputs for the GUI 
    %    hbox            - Box in the lower part to insert the buttons
    %    button          - Buttons for actions of the GUI
    %
    % NewRecordsGUI Methods:
    %   set_uicontrol(obj,parent) - define GUI object for the input
    %   set_default(obj, default) - write default value ("if applicable")
    %   get_value(obj)            - read value written by user
    %   check_input(obj, input)   - check if input is correct
    
    %_________________________________________________________________________________________________
    properties (Constant)
        
        %Images for buttons in GUI
        DIR_IMAGE             = fullfile(fileparts(mfilename('fullpath')), 'Images')
        
        % General GUI Properties
        GUI_NAME              = 'Add user to lab'
        GUI_IS_SMALLSCREEN    = ScreenProperties.checkMonitorSize()
        GUI_POSITION          = [0 45 -1 -45]
        GUI_POSITION_MODE     = 'OuterPosition'
        GUI_FONT              = conditional(AnimalDatabase.GUI_IS_SMALLSCREEN, 9, 14)
        
        % Title part Properties
        TITLE_FONTSIZE        = 15
        TITLE_MESSAGE         = 'Add new users to the database: '
        TITLE_BKG_CLR         = [1 1 1]*0.97;
        TITLE_CLR             = [0 0 0];
        
        % Grid Properties
        GRID_NUM_COLUMNS       = 2
        
        % Labels Properties
        LABEL_FONTSIZE        = conditional(ScreenProperties.IS_SMALL_SCREEN, 10, 14)
        LABEL_BKG_CLR         = [1 1 1]*0.97;
        LABEL_TOOL_TIP_START  = '<html><div style="font-size:12px">'
        LABEL_TOOL_TIP_END    = '</div></html>'
        LABEL_CLR             = [0 0 0];
        
        % Vbox Properties
        VBOX_SPACING          = 10
        VBOX_HEIGHTS          = [30 -1 60]
        
        % Hbox Properties
        HBOX_SPACING          = 10
        HBOX_WIDTHS          = [-1 60]
        
        % Buttons Properties
        BUTTON_SIZE           = [50 50]
        BUTTON_IMAGE          = fullfile(NewRecordsGUI.DIR_IMAGE, 'add_button_image.png')
        
    end
    
    %_________________________________________________________________________________________________
    properties (Access = protected, Transient)
        
        figGUI
        panel
        vbox
        title
        grid
        GUI_inputs
        GUI_inputs_info
        hbox
        button
        
    end
    
    %_________________________________________________________________________________________________
    properties (SetAccess = protected)
        
        DatabaseTable
        GUI_info
        
    end
    
    methods
        
        function delete_previous(~)
            % Close opened GUI if we have to open it again
            
            %Get all open figures
            figHandles = findobj('Type', 'figure');
            
            % If we find a figure with the same name we close it
            for i=1:length(figHandles)
                if strcmp(figHandles(i).Name,NewRecordsGUI.GUI_NAME)
                    delete(figHandles(i))
                end
            end
            
        end
        
        function obj = NewRecordsGUI()
            % Class constructor, define initial object properties
            %
            % Outputs:
            % obj = NewRecordsGUI object
            
            %Delete previous opened figures
            obj.delete_previous();
            
            %Get reference from tables to update
            obj.DatabaseTable = DataJointLabUserTable();
            %Set useful information for the GUI inputs in order to create
            %the GUI
            obj.GUI_inputs_info = obj.DatabaseTable.GUI_info;
            %Actually create the GUI
            obj.create_gui();
            
        end
        
    end
    
    
end
