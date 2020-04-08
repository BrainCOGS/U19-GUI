function GUI_add_user(obj, hobject, event)
% Function called when add user button is pressed
% Reads and check input by the user and insert record if everything is
% correct
% Inputs:
% obj          = AddRecordsGUI object
%
% Outputs
% title        = GUI object for the title

% Disable buttons while processing data
for i=1:length(obj.button)
    set(obj.button, 'Enable', 'off');
end

% Initialize status and error message
status = true;
error_msg = {'Error: Data could not be inserted'};
error_msg(end+1) = {''};
struct_insert = struct;

% For each input
for i = 1:length(obj.GUI_inputs)
    
    GUI_input = obj.GUI_inputs{i};
    %Read value written by user
    struct_insert.(GUI_input.name) = GUI_input.get_value();
    %Check if value is something accepted for the database
    [ac_status, ac_error] = GUI_input.check_input(struct_insert.(GUI_input.name));
    
    %Update status and possible error messages
    status = and(status, ac_status);
    if ~ac_status
        error_msg(end+1) = {ac_error};
    end
    
end

% If there is at least one mistake in inputs
if ~status
    %Show error message for each mistaken input
    msgbox(error_msg, 'Error','error');
    
% If there is no error in input
else
    
    
    try
        %Try to insert record to database
        obj.DatabaseTable.insert_user(struct_insert);
        msgbox({'Record added succesfully'});
        %And close GUI
        obj.close_figure();
        
    catch e 
        %If there is a problem adding the record it shows corresponding error
        error_msg = {sprintf('The identifier was:\n%s',e.identifier)};
        error_msg(end+1) = {sprintf('There was an error! The message was:\n%s',e.message)};
        msgbox(error_msg, 'Error','error');
    end
    
end


end

