% Validation function to ensure that the entered string is not part of a preexisting list
function [input, complaint] = notInListValidator(input, eventData, existing, complaint, comparator)

  if nargin < 5
    comparator    = @strcmp;
  end
  
  if any(comparator(input,existing))
    input         = '';
  else
    complaint     = '';
  end
  
end
