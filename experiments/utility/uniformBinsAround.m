%%
%   Bin centers for a uniform division of the range xMin to xMax into nBins
function centers = uniformBinsAround(xMin, xMax, xMiddle, dx)

  if nargin < 4
    dx        = xMiddle;
    xMiddle   = xMax;
    nBins     = xMin;
    half      = floor( nBins/2 );
    centers   = linspace(xMiddle - half*dx, xMiddle + half*dx, 2*half + 1);
    
  else
    nLo       = round((xMiddle - xMin) / dx);
    nUp       = round((xMax - xMiddle) / dx);
    centers   = (-nLo:nUp) * dx;
  end

end
