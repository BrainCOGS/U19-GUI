function issue = withinRangeConfirmation(input, refValue, maxRelDiff, format)
  
  if nargin < 4 || isempty(format)
    format      = 'This is %.4g%% different from the reference value %.4g. Continue anyway?';
  end
  
  refDiff       = (input - refValue) / refValue;
  if abs(refDiff) > maxRelDiff
    issue       = sprintf(format, refDiff*100, refValue);
  else
    issue       = '';
  end
  
end
