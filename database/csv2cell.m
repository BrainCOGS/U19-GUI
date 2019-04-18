%% Parse a comma-separated-value (CSV) text block into a cell array.
function data = csv2cell(text)
  
  data        = {};
  row         = 1;
  col         = 1;
  pos         = 0;
  
  while pos < numel(text)
    %% Get a single token at the time in order to properly handle quotes
    [token,count] = textscan( text(pos+1:end), '%q', 1                    ...
                            , 'Delimiter'             , {',','\n'}        ...
                            , 'MultipleDelimsAsOne'   , false             ...
                            );
    data{row,col} = token{:}{:};
    pos           = pos + count;

    switch text(pos)
      case ','
        col   = col + 1;
      case char(10)
        row   = row + 1;
        col   = 1;
      otherwise
        if pos < numel(text)
          error('TrainingDatabase:readFromDatabase', 'Invalid delimiter encountered during scan');
        end
    end
  end

end
