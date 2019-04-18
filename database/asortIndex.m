% ASORTINDEX   Naturally sorted numeric index for columns of a cell table, which can either have numeric or string data.
function [numIndex, values] = asortIndex(table, direction)
  
  if nargin < 2 || isempty(direction)
    direction           = 'ascend';
  end
  
  %% Convert alphabetical to numeric indices
  numIndex              = nan(size(table));
  values                = cell(1,size(table,2));
  for iCol = 1:size(table,2)
    %% Get rank of unique values
    [data,~,iData]      = unique(table(:,iCol));
    isNumber            = cellfun(@isnumeric, data);
    if all(isNumber)
      [values{iCol}, indices]   ...
                        = sort(data, direction);
    elseif all(~isNumber)
      order             = asort(data, '-s', direction);
      indices           = [order.aix; order.six; order.tix];
      values{iCol}      = [order.anr; order.snr; order.str];
    else
      error('asortrows:input', 'Cannot handle mixed numeric and non-numeric types within a column.');
    end
    
    %% Assign numerical ranks to data 
    ranks               = nan(size(indices));
    ranks(indices)      = 1:numel(indices);
    numIndex(:,iCol)    = ranks(iData);
  end

end
