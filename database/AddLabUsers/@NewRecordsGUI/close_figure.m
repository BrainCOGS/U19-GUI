function close_figure(obj, handle, event)
%Simple function to handle close event
%
% Inputs:
% obj = AddRecordsGUI object

% Delete object if needed
if ishghandle(obj.figGUI)
    delete(obj.figGUI);
end
obj.figGUI              = gobjects(0);

end