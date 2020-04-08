classdef GUI_Input_HBox < GUI_Input
    % GUI_Input_HBox   Summary of GUI_Input_Edit
    % GUI_Input implementarion with functions for a hbox (edit array) uicontrol
    % This object is intended for blob values in the database
    %
    % GUI_Input_HBox Properties:
    %   GUI_INPUT_FONTSIZE  - Fontsize of the input
    %   GUI_INPUT_BKG_CLR   - Background color of the input
    %   GUI_INPUT_FOR_CLR   - Foreground color of the input
    %   GUI_INPUT_SPACING   - Spacing between edits
    %   name                - Field name that input is attached to
    %   uicontrolable       - GUI object for the input
    %   uiedits             - uiobject edits cell array
    %   datatype            - Field datatype for database
    %
    % GUI_Input_HBox Methods:
    %   create_edit(obj, parent)       - define 1 uiobject edit for the array
    %   set_uicontrol(obj,parent)      - define GUI object for the input
    %   set_default(obj, default)      - write default value ("if applicable")
    %   get_value(obj)                 - read value written by user
    %   check_input(obj, input)        - check if input is correct
    
    properties (Constant)
        GUI_INPUT_SPACING = 20
    end
    
    properties
        name
        uicontrolable
        uiedits
        datatype
        size
    end
    
    methods
        
        function uiedit = create_edit(obj, parent)
            %Define uicontrol (edit) for the input array
            %
            % Inputs:
            % obj = GUI_Input_HBox object
            % parent = uicontrol parent of the GUI_input
            %
            % Outputs:
            % uicontrolable = uicontrol edit object for the input
            
            uiedit = uicontrol ( ...
                'Parent', parent, ...
                'Style', 'edit', ...
                'FontSize', obj.GUI_INPUT_FONTSIZE, ...                             ...
                'BackgroundColor', obj.GUI_INPUT_BKG_CLR, ...
                'ForegroundColor', obj.GUI_INPUT_FOR_CLR);
            
            
        end
        
        function [uicontrolable, uiedits] = set_uicontrol(obj, parent)
            %Define uicontrol (hbox) for the input
            %
            % Inputs:
            % obj = GUI_Input_HBox object
            % parent = uicontrol parent of the GUI_input
            %
            % Outputs:
            % uicontrolable = uicontrol edit object for the input
            
            uicontrolable = uix.HBox ( ...
                'Parent', parent, ....
                'Spacing', obj.GUI_INPUT_SPACING, ......
                'BackgroundColor', obj.GUI_INPUT_BKG_CLR);
            
            uiedits = cell(obj.size, 1);
            for i = 1:obj.size
                
                uiedits{i} = obj.create_edit(uicontrolable);
                
            end
            
            
        end
        
        function values = get_value(obj)
            % Read value written by user
            %
            % Inputs:
            % obj = GUI_Input_HBox object
            %
            % Outputs:
            % values = values written by user (transformed if needed by GUI)
            
            %Create cell for writting all edit values
            values = cell(1,obj.size);
            for i=1:obj.size
                %Read each one of the edits
                values{i} = get(obj.uiedits{i}, 'String');
                %Transform if applicable
                if strcmp(obj.datatype,'numeric array')
                    transform = str2double(values{i});
                    if ~isnan(transform)
                        values{i} = transform;
                    end
                end
            end
            
            %Transform from cell to array if applicable
            %Normally blob inputs in database are numeric arrays
            if strcmp(obj.datatype,'numeric array')
                if all(cellfun(@isnumeric,values,'UniformOutput',true))
                    values = cell2mat(values);
                end
            end
            
        end
        
        function [status, error] = check_input(obj, input)
            % Check fot data compliance (w/datatype defined by object)
            %
            % Inputs:
            % obj = GUI_Input_HBox object
            % input = Value written (and transformed)
            %
            % Outputs:
            % status = true if input is correct, false otherwise
            % error  = error message to inform user why input is incorrect
            
            status = true;
            error = '';
            %Check if value is string cell
            if strcmp(obj.datatype,'cell string')
                status = iscellstr(input);
                error_msg = ': Input is not conformed of only strings';
                %Check if value is numeric array
            elseif strcmp(obj.datatype,'numeric array')
                status = isnumeric(input) & ~iscell(input);
                error_msg = ': Input is not conformed of only numbers';
            end
            
            %If value is incorrect append field name
            % and correspondent error message
            if ~status
                error = strcat([obj.name error_msg]);
            end
            
        end
        
        function set_default(obj, default)
            %Not defined
        end
        
        function obj = GUI_Input_HBox(parent, name, example_value, datatype)
            % Class constructor, define initial object properties
            %
            % Inputs:
            % parent         = parent object for the GUI_Input_HBox object
            % name           = name of the input field (for database)
            % example_value  = example value for this input
            % datatype       = intended datatype for input
            %
            % Outputs:
            % obj = input object
            
            obj.name = name;
            obj.datatype = datatype;
            obj.size = length(example_value);
            [obj.uicontrolable, obj.uiedits] = obj.set_uicontrol(parent);
            
            
        end
    end
    
end

