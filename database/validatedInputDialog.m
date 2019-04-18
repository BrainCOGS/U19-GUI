% Ask for user input in a validated way.
function answer = validatedInputDialog(title, prompt, value, validatorFcn, confirmFcn, canCancel, fontSize, position, monitor, varargin)
  
  %% Default arguments
  if iscell(prompt)
    nPromptLines        = numel(prompt);
  else
    nPromptLines        = 1;
  end
  if nargin < 5
    confirmFcn          = [];
  end
  if nargin < 6 || isempty(canCancel)
    canCancel           = true;
  end
  if nargin < 7 || isempty(fontSize)
    fontSize            = get(0, 'DefaultAxesFontSize');
  end
  if nargin < 8 || isempty(position)
    position            = [0.4, 0.4, 500, 250 + 50*nPromptLines];
  end
  if nargin < 9 || isempty(monitor)
    monitor             = getMonitorBySize();
  end
  
  %% Create a modal figure with an editbox as input
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
  txtValid              = uicontrol( 'Parent', cnt, 'Style', 'text', 'String', '', 'FontSize', fontSize );
  cntAction             = uix.HButtonBox( 'Parent', cnt, 'Spacing', 10, 'ButtonSize', [150 50] );
  btnOk                 = uicontrol( 'Parent', cntAction, 'Style', 'pushbutton', 'String', 'OK', 'FontSize', fontSize, 'Enable', 'off', 'Callback', @doneFcn );
  if canCancel
    btnCancel           = uicontrol( 'Parent', cntAction, 'Style', 'pushbutton', 'String', 'Cancel', 'FontSize', fontSize, 'Callback', {@doneFcn, true} );
  end
  if isempty(value)
  elseif ischar(value)
    set(edtInput, 'String', value);
  else
    set(edtInput, 'String', num2str(value));
  end
  
  answer                = '';
  set(cnt, 'Heights', [(1+nPromptLines)*35, 45, -1, 45]);
  uicontrol(edtInput);
  
  %% Setup keyboard trap to detect whether or not input is valid
  % http://undocumentedmatlab.com/blog/editbox-data-input-validation
  
  % Get the underlying Java editbox 
  jEditbox              = findjobj(edtInput);
  try                   % Multi-line editboxes are contained within a scroll-panel 
    jEditbox            = handle(jEditbox.getViewport.getView, 'CallbackProperties'); 
  catch                 % probably a single-line editbox 
  end
  set(jEditbox, 'KeyPressedCallback', @enterTrapFcn);
  if ~isempty(value)
    enterTrapFcn(jEditbox, struct('getKeyChar',{''}));
  end
  
  uiwait(fig);
  
  
  %% Callbacks to deal with input
  function enterTrapFcn(jEditBox, eventData)
    if ~isempty(eventData.getKeyChar()) && eventData.getKeyChar() == 27 && canCancel
      %% Allow escape key to put focus on the cancel button
      uicontrol(btnCancel);
      
    elseif isempty(eventData.getKeyChar()) || eventData.getKeyChar() ~= char(10)
      %% For all non-enter inputs, ask the user-specified validator 
      answer                = char(jEditBox.getText);
      if iscell(validatorFcn)
        [answer, complaint] = validatorFcn{1}(answer, eventData, validatorFcn{2:end});
      elseif ~isempty(validatorFcn)
        [answer, complaint] = validatorFcn(answer, eventData);
      else
        complaint           = '';
      end
      
      set(txtValid, 'String', complaint, 'ForegroundColor', [0.8 0 0]);
      if ~isempty(complaint)
        jEditbox.setBorder(javax.swing.border.LineBorder(java.awt.Color.red, 3, false));
        set(btnOk, 'Enable', 'off');
      elseif ~isempty(answer)
        jEditbox.setBorder(javax.swing.border.LineBorder(java.awt.Color.black, 1, false));
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
  
  function doneFcn(handle, event, cancelled)
    if nargin > 2 && cancelled
      answer        = '';
    elseif ~isempty(confirmFcn)
      if iscell(confirmFcn)
        issue       = confirmFcn{1}(answer, confirmFcn{2:end});
      else
        issue       = confirmFcn(answer);
      end
      if ~isempty(issue)
        set(txtValid, 'String', issue, 'ForegroundColor', [0 0 1]);
        jEditbox.setBorder(javax.swing.border.LineBorder(java.awt.Color.blue, 3, false));
        set(btnOk, 'String', 'Confirm');
        confirmFcn  = [];
        return;
      end
    end
    
    delete(fig);
  end
  
end
