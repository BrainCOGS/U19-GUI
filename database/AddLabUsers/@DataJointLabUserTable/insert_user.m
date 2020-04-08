function insert_user(obj, all_values_insert)
% Function that calls database to insert record in tables referenced in
% table_info structure
% Inputs:
% obj               = DataJointLabUserTable object
% all_values_insert = structure with values to insert in table
%

% for each table of the tables_info structure
for table_info = obj.tables_info
        
    table = table_info.table;
    values_insert_table = struct;
    %Select the fields to be written 
    for field = table_info.fields
        field_str = field{:};
        values_insert_table.(field_str) = all_values_insert.(field_str);
        
    end
    %Call datajoint database and insert data
    insert(table, values_insert_table);
    
end

