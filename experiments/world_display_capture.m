function code = world_display_capture
% empty   Code for the ViRMEn experiment empty.
%   code = empty   Returns handles to the functions that ViRMEn
%   executes during engine initialization, runtime and termination.


% Begin header code - DO NOT EDIT
code.initialization = @initializationCodeFun;
code.runtime = @runtimeCodeFun;
code.termination = @terminationCodeFun;
% End header code - DO NOT EDIT


% --- INITIALIZATION code: executes before the ViRMEn engine starts.
function vr = initializationCodeFun(vr)

  vr.posIndex   = 0;
  vr.positions  = vr.exper.userdata.positions;

% --- RUNTIME code: executes on every iteration of the ViRMEn engine.
function vr = runtimeCodeFun(vr)

  pause(1);
  vr.posIndex   = vr.posIndex + 1;
  if vr.posIndex > size(vr.positions,1);
    vr.experimentEnded  = true;
    return;
  end
  
  vr.position   = vr.positions(vr.posIndex,:);
  