function T = merge_GUI_user_info(obj, GUI_info, table_user_info)
% Define some defaults to fields
%
%some obj.GUI_inputs_info.default values are overriden with known values
%

% Convert info from database to table
key_column = 'name';
GUI_infoT = struct2table(GUI_info);

% Check which user defined fields are not found 
fields_not_found = setdiff(table_user_info.name, GUI_infoT.name);

% If some fields not found, warn the user
if ~isempty(fields_not_found)
    err = cell2string(fields_not_found);
    warning(['Some user defined fields not found in table' newline err])
    
    % Merge only those fields that exist in the database table
    [~, imatch] = intersect(table_user_info.name, GUI_infoT.name);
    table_user_info = table_user_info(imatch, :);
end


% Check if there are some columns repeated in both tables
repeated_col = intersect(table_user_info.Properties.VariableNames, ...
                         GUI_infoT.Properties.VariableNames);
                    
%Remove key column from repeated columns (we need that !!)
repeated_col = repeated_col(~contains(repeated_col, key_column));
                     
% Get only fields from database info in case of repeated columns                     
if ~isempty(repeated_col)
    err = cell2string(repeated_col);
    warning(['Some user defined columns were already defined in database' newline err])
    columns_keep = ~contains(table_user_info.Properties.VariableNames, repeated_col);
    table_user_info = table_user_info(:, columns_keep);
end

%Merge tables
T = outerjoin(table_user_info, GUI_infoT, 'MergeKeys', true, 'Keys', key_column);

%Go back to struct
T = table2struct(T);

end

