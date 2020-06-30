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
        FORCED_DEFAULT        = struct(...
            'contact_via',          'email', ...
            'primary_tech',         'N/A', ...
            'tech_responsibility',  'yes', ...
            'day_cutoff_time',      [16 30], ...
            'slack_webhook',        'https://hooks.slack.com/services/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', ...
            'watering_logs',        'https://docs.google.com/spreadsheets/d/1aLcGLTZC78Tx0F07Q0cNiNp1jM7Zg4ceaduXOixBbx8/' ...
            );
        
        FORCED_INPUT        = {...
            'user_id', ...
            'user_nickname'
            };
        
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
        forced_defaults = declare_forced_defaults(obj);
        forced_inputs = declare_forced_inputs(obj);
        
        function obj = DataJointLabUserTable()
            %----- Class constructor, defining structures
            
            [obj.GUI_info, obj.tables_info] = obj.get_GUI_table_info();
            forced_defaults = declare_forced_defaults(obj);
            [obj.GUI_info(:).default] = deal(forced_defaults{:});
            forced_input  = declare_forced_inputs(obj);
            [obj.GUI_info(:).forced_input] = deal(forced_input{:});
            
        end
        
    end
    
    
end
