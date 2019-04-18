% Confirmation function to ensure that the entered string is not part of a preexisting list
function issue = notInListConfirmation(input, existing, issue, comparator)

  if nargin < 4
    comparator    = @strcmp;
  end
  if ~any(comparator(input,existing))
    issue         = '';
  end
  
end
