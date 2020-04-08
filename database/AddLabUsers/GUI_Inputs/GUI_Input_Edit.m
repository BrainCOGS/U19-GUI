classdef GUI_Input_Edit < GUI_Input
    % GUI_Input_Edit   Summary of GUI_Input_Edit
    % GUI_Input implementarion with functions for a edit uicontrol
    %
    % GUI_Input_Edit Properties:
    %   GUI_INPUT_FONTSIZE  - Fontsize of the input
    %   GUI_INPUT_BKG_CLR   - Background color of the input
    %   GUI_INPUT_FOR_CLR   - Foreground color of the input
    %   name                - Field name that input is attached to
    %   uicontrolable       - GUI object for the input
    %   datatype            - Field datatype for database 
    %
    % GUI_Input_Edit Methods:
    %   set_uicontrol(obj,parent) - define GUI object for the input
    %   set_default(obj, default) - write default value ("if applicable")
    %   get_value(obj)            - read value written by user
    %   check_input(obj, input)   - check if input is correct

    properties (Constant)
    end
    
    properties
        name
        uicontrolable
        datatype
    end
    
    methods
        
        function uicontrolable = set_uicontrol(obj, parent)
            %Define uicontrol (edit) for the input
            %
            % Inputs:
            % obj = GUI_input_Edit object
            % parent = uicontrol parent of the GUI_input
            %
            % Outputs:
            % uicontrolable = uicontrol edit object for the input
            
            uicontrolable = uicontrol ( ...
                'Parent', parent, ...
                'Style', 'edit', ...
                'FontSize', obj.GUI_INPUT_FONTSIZE, ...                             ...
                'BackgroundColor', obj.GUI_INPUT_BKG_CLR, ...
                'ForegroundColor', obj.GUI_INPUT_FOR_CLR);
            
            
        end
        
        function value = get_value(obj)
            % Read value written by user
            %
            % Inputs:
            % obj = GUI_input_Edit object
            %
            % Outputs:
            % value = value written by user (transformed if needed by GUI)
            
            value = get(obj.uicontrolable, 'String');
            %If datatype for the object is numeric, try to convert it
            if strcmp(obj.datatype,'numeric')
                try
                    value = str2double(value);
                catch
                end
            end
            
        end
            
                  
        function set_default(obj, default)
            % Write default value for the input
            %
            % Inputs:
            % obj = GUI_input_Edit object
            % default = default value to write
            
            if ~isempty(default)
                set(obj.uicontrolable, 'String', default);
            end
                        
        end
        
        function [status, error] = check_input(obj, input)
            % Check fot data compliance (w/datatype defined by object) 
            %
            % Inputs:
            % obj = GUI_input_Edit object
            % input = Value written (and transformed) 
            %
            % Outputs:
            % status = true if input is correct, false otherwise
            % error  = error message to inform user why input is incorrect
             
            status = true;
            error = '';
            %Check if value is numeric
            if strcmp(obj.datatype,'numeric')
                status = isnumeric(input);
                error_msg = ': Input is not numeric';
            %Check if value is string
            elseif strcmp(obj.datatype,'string')
                status = ischar(input);
                error_msg = ': Input is not string';
            end
            
            %If value is incorrect append field name 
            % and correspondent error message
            if ~status
                error = strcat([obj.name error_msg]);
            end
            
        end
        
        function obj = GUI_Input_Edit(parent, name, default, datatype)
            % Class constructor, define initial object properties
            %
            % Inputs:
            % parent   = parent uiobject for the GUI_input_Edit object
            % name     = name of the input field (for database)
            % default  = default value for input
            % datatype = intended datatype for input
            %
            % Outputs:
            % obj = input object
            
            obj.name = name;
            obj.datatype = datatype;
            obj.uicontrolable = obj.set_uicontrol(parent);
            obj.set_default(default)
            
         
        end
    end
    
end

