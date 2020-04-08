classdef (Abstract) GUI_Input
    % GUI_Input   Summary of GUI_Input
    % Abstract class that defines an interface for different types of 
    % inputs in a GUI. (Edits, Popupmenu and HBox or list of edits)
    %
    % GUI_Input Properties:
    %   GUI_INPUT_FONTSIZE  - Fontsize of the input
    %   GUI_INPUT_BKG_CLR   - Background color of the input
    %   GUI_INPUT_FOR_CLR   - Foreground color of the input
    %   name                - Field name that input is attached to
    %   uicontrolable       - GUI object for the input
    %   datatype            - Field datatype for database 
    %
    % GUI_Input Methods:
    %   set_uicontrol(obj,parent) - define GUI object for the input
    %   set_default(obj, default) - write default value ("if applicable")
    %   get_value(obj)            - read value written by user
    %   check_input(obj, input)   - check if input is correct
    
    properties
        
        GUI_INPUT_FONTSIZE        = conditional(ScreenProperties.IS_SMALL_SCREEN, 9, 14)
        GUI_INPUT_BKG_CLR         = [1 1 1];
        GUI_INPUT_FOR_CLR         = [0 0 0];
        
    end
    
    properties (Abstract)
        
        name
        uicontrolable
        datatype
        
    end
    
    methods(Abstract)
        
        set_uicontrol(obj,parent)
        set_default(obj, default)
        
        get_value(obj)
        check_input(obj, input)
        
    end
    
end

