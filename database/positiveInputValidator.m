% Validation function for use entry of a positive number
function [answer, complaint] = positiveInputValidator(input, eventData)

  answer        = str2double(input);
  if ~isfinite(answer) || ~(answer > 0)
    answer      = [];
    complaint   = 'Input must be a positive number';
  else
    complaint   = '';
  end
  
end
