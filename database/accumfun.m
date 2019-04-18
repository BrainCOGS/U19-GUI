%% Concatenate results of arrayfun() along the specified dimension.
function varargout = accumfun(dim, func, varargin)

  if iscell(varargin{1})
    fcn           = @cellfun;
  else
    fcn           = @arrayfun;
  end
  
  varargout       = cell(1,max(1,nargout));
  [varargout{:}]  = fcn(func, varargin{:}, 'UniformOutput', false);
  varargout       = cellfun(@(x) cat(dim, x{:}), varargout, 'UniformOutput', false);
  
end
