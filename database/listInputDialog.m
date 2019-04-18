% Ask for user input from either a drop-down list or freeform entry
function [answer, index] = listInputDialog(title, prompt, list, validatorFcn, allowMulti, canCancel, fontSize, position, monitor, varargin)
  
  %% Default arguments
  if iscell(prompt)
    nPromptLines        = numel(prompt);
  else
    nPromptLines        = 1;
  end
  if nargin < 5
    allowMulti          = false;
  end
  if nargin < 6 || isempty(canCancel)
    canCancel           = true;
  end
  if nargin < 7 || isempty(fontSize)
    fontSize            = get(0, 'DefaultAxesFontSize');
  end
  if nargin < 8 || isempty(position)
    position            = [0.4, 0.4, 600, 230 + 50*nPromptLines + 30*min(10,numel(list))];
  end
  if nargin < 9 || isempty(monitor)
    monitor             = getMonitorBySize();
  end
  
  %% Special case for when a list of pre-selected values are provided
  if iscell(allowMulti)
    [sel,value]         = ismember(list, allowMulti);
    value(~sel)         = [];
    allowMulti          = true;
  else
    value               = 1;
  end
  if iscell(validatorFcn) && islogical(validatorFcn{1})
    displayList         = validatorFcn{2};
    validatorFcn        = validatorFcn{1};
  else
    displayList         = [];
  end
  
  
  %% Create a modal figure with an editbox and listbox as inputs
  fig                   = makePositionedFigure( position, monitor, [], varargin{:}              ...
                                              , 'MenuBar'         , 'none'                      ...
                                              , 'NumberTitle'     , 'off'                       ...
                                              , 'ToolBar'         , 'none'                      ...
                                              , 'WindowStyle'     , 'modal'                     ...
                                              , 'Name'            , title                       ...
                                              , 'CloseRequestFcn' , ''                          ...
                                              );
  cnt                   = uix.VBox( 'Parent', fig, 'Spacing', 5, 'Padding', 10 );
  txtPrompt             = uicontrol( 'Parent', cnt, 'Style', 'text', 'String', prompt, 'FontSize', fontSize );
  edtInput              = uicontrol( 'Parent', cnt, 'Style', 'edit', 'FontSize', fontSize );
  lstInput              = uicontrol( 'Parent', cnt, 'Style', 'listbox', 'String', list, 'FontSize', fontSize, 'Value', value );
  txtValid              = uicontrol( 'Parent', cnt, 'Style', 'text', 'String', '', 'FontSize', fontSize, 'ForegroundColor', [0.8 0 0] );
  cntAction             = uix.HButtonBox( 'Parent', cnt, 'Spacing', 10, 'ButtonSize', [150 50] );
  btnOk                 = uicontrol( 'Parent', cntAction, 'Style', 'pushbutton', 'String', 'OK', 'FontSize', fontSize, 'Callback', @doneFcn );
  if allowMulti
    set(lstInput, 'Min', 0, 'Max', 3);
  else
    set(lstInput, 'Callback', {@setEditText, list});
  end
  if ~isempty(displayList)
    set(edtInput, 'Enable', 'inactive', 'BackgroundColor', [1 1 1]*0.97);
    set(lstInput, 'Callback', {@setEditText, displayList});
  elseif isequal(validatorFcn, false)
    set(edtInput, 'Visible', 'off');
  elseif ~isempty(validatorFcn)
    set(btnOk, 'Enable', 'off');
  end
  if canCancel
    btnCancel           = uicontrol( 'Parent', cntAction, 'Style', 'pushbutton', 'String', 'Cancel', 'FontSize', fontSize, 'Callback', {@doneFcn, true} );
  end
  
  answer                = '';
  index                 = [];
  set(cnt, 'Heights', [(1+nPromptLines)*35, 45, -1, 45, 45]);
  uicontrol(edtInput);
  
  %% Setup keyboard trap to detect whether or not input is valid
  % http://undocumentedmatlab.com/blog/editbox-data-input-validation
  
  % Get the underlying Java editbox 
  jEditBox              = findjobj(edtInput);
  try                   % Multi-line editboxes are contained within a scroll-panel 
    jEditBox            = handle(jEditBox.getViewport.getView, 'CallbackProperties'); 
  catch                 % probably a single-line editbox 
  end
  set(jEditBox, 'KeyPressedCallback', @enterTrapFcn);
  if ~isempty(displayList)
    executeCallback(lstInput);
  end
  
  uiwait(fig);
  
  
  %% Callbacks to deal with input
  function enterTrapFcn(jObject, eventData)
    if ~isempty(eventData) && eventData.getKeyChar() == 27 && canCancel
      %% Allow escape key to put focus on the cancel button
      uicontrol(btnCancel);
      
    elseif isempty(eventData) || eventData.getKeyChar() ~= char(10)
      %% For all non-enter inputs, ask the user-specified validator 
      answer                = char(jObject.getText);
      if iscell(validatorFcn)
        [answer, complaint] = validatorFcn{1}(answer, eventData, validatorFcn{2:end});
      elseif isa(validatorFcn, 'function_handle')
        [answer, complaint] = validatorFcn(answer, eventData);
      else
        complaint           = '';
      end
      
      set(txtValid, 'String', complaint);
      if ~isempty(complaint)
        jObject.setBorder(javax.swing.border.LineBorder(java.awt.Color.red, 3, false));
        set(btnOk, 'Enable', 'off');
      elseif ~isempty(answer)
        jObject.setBorder(javax.swing.border.LineBorder(java.awt.Color.black, 1, false));
        set(btnOk, 'Enable', 'on');
      end
      
    elseif strcmp(get(btnOk, 'Enable'), 'on')
      %% Allow the enter key to trigger the OK button
      executeCallback(btnOk);
      
    else
      %% Not possible to exit
      beep;
    end
  end
  
  %% Callbacks to deal with input
  function setEditText(handle, event, displayList)
    set(edtInput, 'String', displayList{get(handle, 'Value')});
    drawnow;
    enterTrapFcn(jEditBox, []);
  end
  
  function doneFcn(handle, event, cancelled)
    if nargin > 2 && cancelled
      answer            = '';
      index             = [];
    else
      drawnow;
      answer            = strtrim(get(edtInput, 'String'));
      index             = get(lstInput, 'Value');
      if allowMulti
        if isempty(answer)
          answer        = {};
        else
          answer        = {answer};
        end
        answer          = [answer, list(index)];
      elseif isequal(validatorFcn, false)
      	answer          = list(index);
      end
    end
    delete(fig);
  end
  
end
