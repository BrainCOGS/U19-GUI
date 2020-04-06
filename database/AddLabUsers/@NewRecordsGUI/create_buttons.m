function button = create_buttons(obj, parent)
% Create a simple add record button for the GUI
%
% Inputs:
% obj          = AddRecordsGUI object
% parent       = Parent GUI object for the button
%
% Outputs
% button        = GUI object for the button


%Read and resize image for the button
img = imread(obj.BUTTON_IMAGE);
img = imresize(img, obj.BUTTON_SIZE);
img = image(img);
img = img.CData;

%Create button
button  = uicontrol ( ...
    'Parent'  , parent,              ...
    'Style'   , 'pushbutton',        ...
    'String'  , '',                  ...
    'cdata'   , img,                 ...
    'Callback', @obj.GUI_add_user    ...
    );

end