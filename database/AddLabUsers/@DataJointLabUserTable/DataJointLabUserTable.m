classdef DataJointLabUserTable
    % DataJointLabUserTable   Summary of DataJointLabUserTable
    % Define a simple interface to define records to be added for specific
    % tables
    %
    % DataJointLabUserTable main Properties:
    %    GUI_info       - structure with information for each field of the tables
    %                     that will update for defining the GUI
    %    tables_info    - reference for all the tables that will be updated
    %    
    % DataJointLabUserTable Methods:
    % get_GUI_table_info(obj,parent) - Function that defines two structures with information about tables that
                                       % will be updated
    % insert_user(obj, all_values_insert) - Function that calls database to insert record in tables referenced in
    %                                       table_info structure
    % get_values_table_field(~, table, field, sort_limit) -Function to get specific fields from table
    properties (Constant)
        
        %dj_conn      = getdjconnection('u19_', 'datajoint00.pni.princeton.edu');
        
    end
    
    %_________________________________________________________________________________________________
    properties (SetAccess = protected)
        
        GUI_info
        tables_info
        
    end
    
    %_________________________________________________________________________________________________
    methods
        
        [GUI_info, tables_update] = get_GUI_table_info(obj);
        example_value = get_values_table_field(obj, table, field, sort_limit);
        insert_user(obj, all_values_insert);  
                
        function obj = DataJointLabUserTable()
            %----- Class constructor, defining structures
            
            [obj.GUI_info, obj.tables_info] = obj.get_GUI_table_info();
            
                        
        end
        
    end
    
    
end
