% Validation function for use entry of a number
function [answer, complaint] = numberInputValidator(input, eventData, realOnly)

  if nargin < 3 || isempty(realOnly)
    realOnly    = false;
  end
  
  answer        = str2double(input);
  if isnan(answer) || (realOnly && ~isreal(answer))
    answer      = [];
    if realOnly
      complaint = 'Input must be a real number';
    else
      complaint = 'Invalid input: must be a number';
    end
  else
    complaint   = '';
  end
  
end
