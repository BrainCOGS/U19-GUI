function [num] = numobj(x, noCellStr, noStruct)
%  NUMOBJ    Like numel(), but treats strings as a singleton.

  if nargin < 2
    noCellStr = false;
  end
  if nargin < 3
    noStruct  = false;
  end

  if      ischar(x)                       ...
      ||  (noCellStr && iscellstr(x))     ...
      ||  (noStruct && isstruct(x))       ...
    num       = 1;
  else
    num       = numel(x);
  end
  
end
