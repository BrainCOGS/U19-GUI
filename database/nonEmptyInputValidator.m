% Validation function for entry of anything at all
function [answer, complaint] = nonEmptyInputValidator(input, eventData)

  answer        = strtrim(input);
  if isempty(answer)
    complaint   = 'Input must not be empty';
  else
    complaint   = '';
  end
  
end
