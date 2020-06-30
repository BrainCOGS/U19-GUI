classdef GUI_Input_Popup < GUI_Input
    % GUI_Input_Popup   Summary of GUI_Input_Edit
    % GUI_Input implementarion with functions for a popmenu uicontrol
    %
    % GUI_Input_Popup Properties:
    %   GUI_INPUT_FONTSIZE  - Fontsize of the input
    %   GUI_INPUT_BKG_CLR   - Background color of the input
    %   GUI_INPUT_FOR_CLR   - Foreground color of the input
    %   name                - Field name that input is attached to
    %   uicontrolable       - GUI object for the input
    %   datatype            - Field datatype for database
    %   value_list          - List of possible values for input
    %
    % GUI_Input_Popup Methods:
    %   set_uicontrol(obj,parent)        - define GUI object for the input
    %   set_default(obj, default)        - write default value ("if applicable")
    %   get_value(obj)                   - read value written by user
    %   check_input(obj, input)          - check if input is correct
    %   set_value_list(obj, value_list)  - 
    
    properties
        name
        uicontrolable
        datatype
        forced_input
        value_list
    end
    
    methods
        
        function uicontrolable = set_uicontrol(obj, parent)
            %Define uicontrol (popupmenu) for the input
            %
            % Inputs:
            % obj = GUI_input_Popup object
            % parent = uicontrol parent of the GUI_input
            %
            % Outputs:
            % uicontrolable = uicontrol edit object for the input
            
            uicontrolable = uicontrol ( ...
                'Parent', parent, ...
                'Style', 'popupmenu', ...
                'String', {''}, ...
                'Value', 1, ...
                'FontSize', obj.GUI_INPUT_FONTSIZE, ...                             ...
                'BackgroundColor', obj.GUI_INPUT_BKG_CLR, ...
                'ForegroundColor', obj.GUI_INPUT_FOR_CLR);
            
        end
        
        function value = get_value(obj)
            % Read value written by user
            %
            % Inputs:
            % obj = GUI_input_Popup object
            %
            % Outputs:
            % value = value written by user 
            
            list = get(obj.uicontrolable, 'String');
            idx = get(obj.uicontrolable, 'Value');
            value = list{idx};
            
        end
        
        function values = set_value_list(obj, values)
            % Write all possible values for input
            %
            % Inputs:
            % obj = GUI_input_Popup object
            % values = value list to write for the popupmenu
            
            set (obj.uicontrolable, 'String', values);
            
        end
        
        function set_default(obj, default)
            % Write default value for the input
            %
            % Inputs:
            % obj = GUI_input_Popup object
            % default = default value to write
            
            if ~isempty(default)
                index  = find(strcmpi(get(obj.uicontrolable, 'String'), default), 1);
                if isempty(index)
                    error('Default not found');
                end
                set( obj.uicontrolable, 'Value', index );
            end
            
        end
        
        function [status, error] = check_input(obj, input)
            % Check fot data compliance (w/datatype defined by object) 
            %
            % Inputs:
            % obj = GUI_input_Popup object
            % input = Value written (and transformed) 
            %
            % Outputs:
            % status = true if input is correct, false otherwise
            % error  = error message to inform user why input is incorrect
            
            status = true;
            error = '';
            %Check if numeric value is in cell of accepted values
            if strcmp(obj.datatype,'numeric')
                status = any(cellfun(@(x) x==input,obj.value_list));
                error_msg = ': Input is not in accepted values';
            %Check if string value is in cell of accepted values
            elseif strcmp(obj.datatype,'string')
                status = any(find(strcmp(obj.value_list, input),1));
                error_msg = ': Input is not in accepted values';
            end
            
            %Check if input is empty and raise error if required
            if isempty(input) && (obj.forced_input)
                status = false;
                error_msg = ': Input cannot be leaved empty';
            end
            
            %If value is incorrect append field name 
            % and correspondent error message
            if ~status
                error = strcat([obj.name error_msg]);
            end
            
        end
        
        function obj = GUI_Input_Popup(parent, field_info)
            % Class constructor, define initial object properties
            %
            % Inputs:
            % parent      = parent uiobject for the GUI_input_Popup object
            % field_info  = structure with data from field
            %          name           = name of the input field (for database)
            %          datatype       = intended datatype for input
            %          default        = default value for input
            %          forced_input   = true/false, to indicate if field
            %                           can be leaved empty
            %          list_values    = list of accepted values for input
            %
            % Outputs:
            % obj = input object
            
            obj.name = field_info.name;
            obj.datatype = field_info.datatype;
            obj.uicontrolable = obj.set_uicontrol(parent);
            obj.value_list = obj.set_value_list(field_info.list_values);
            obj.set_default(field_info.default);
            
        end
    end
    
end

