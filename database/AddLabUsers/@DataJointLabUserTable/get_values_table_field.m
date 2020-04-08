function example_value = get_values_table_field(~, table, field, sort_limit)
% Function to get specific fields from table
% Inputs:
% obj               = DataJointLabUserTable object
% table             = Reference to table in the database
% field             = Name of the field to read
% sort_limit        = Optional argument for sorting or limiting query
%
% Outputs
% example_value     = Result from the query


%If sort_limit argument is not present, will be defined as empty string
if nargin <= 3
    sort_limit = '';
end

if ~isempty(sort_limit)
    example_value = fetchn(table, field, sort_limit);
    %If only one record needed for the query extract cell value
    if strcmp(sort_limit,'LIMIT 1')
        example_value = example_value{:};
    end
else
    example_value = fetchn(table, field);
    example_value = example_value(:);  
end

end