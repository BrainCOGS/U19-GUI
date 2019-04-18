classdef FilterState < uint32
  
  enumeration
    OR(false)
    AND(true)
    Off(inf)
  end
  
  methods (Static)
    function value = default()
      value   = FilterState.Unknown;
    end
    
    function values = all()
      values  = enumeration('FilterState');
    end
    
    function values = selectable()
      values  = enumeration('FilterState');
    end
    
    function rgb = color(value)
      rgb   = [0 0 0];
    end
    
    function rgb = background(value)
      switch value
        case FilterState.OR;        rgb   = [227 203 163]/255;
        case FilterState.AND;       rgb   = [218 199 242]/255;
        otherwise;                  rgb   = [1 1 1]*0.6;
      end
    end
    
    function str = html(value)
      str = char(value);
    end
    
    function expr = expression(value)
      switch value
        case FilterState.OR;        expr  = '|';
        case FilterState.AND;       expr  = '&';
        otherwise;                  expr  = '';
      end
    end
    
    function next = cycle(value, direction)
      if nargin < 1
        direction = 1;
      end
      
      values      = enumeration('FilterState');
      index       = find(values == value);
      if isempty(index)
        error('FilterState:cycle', 'value must be a FilterState enumerated type.');
      end
      
      index       = mod(index-1 + direction, numel(values)) + 1;
      next        = values(index);
    end
  end
  
end
