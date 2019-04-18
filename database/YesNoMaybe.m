classdef YesNoMaybe < uint32
  
  enumeration
    No(false)
    Yes(true)
    Unknown(inf)
  end
  
  methods (Static)
    function value = default()
      value   = YesNoMaybe.Unknown;
    end
    
    function values = all()
      values  = setdiff(enumeration('YesNoMaybe'), YesNoMaybe.default());
    end
    
    function values = selectable()
      values  = enumeration('YesNoMaybe');
    end
    
    function rgb = color(value)
      rgb   = [0 0 0];
    end
    
    function rgb = background(value)
      switch value
        case YesNoMaybe.No;       rgb   = [0.95 0 0];
        case YesNoMaybe.Yes;      rgb   = [119 217 0]/255;
        otherwise;                rgb   = [1 1 1]*0.6;
      end
    end
    
    function str = html(value)
      switch value
        case YesNoMaybe.No;       str   = '&#10007;';
        case YesNoMaybe.Yes;      str   = '&#10003;';
        otherwise;                str   = '';
      end
    end
    
    function next = cycle(value, direction)
      if nargin < 1
        direction = 1;
      end
      
      values      = enumeration('YesNoMaybe');
      index       = find(values == value);
      if isempty(index)
        error('YesNoMaybe:cycle', 'value must be a YesNoMaybe enumerated type.');
      end
      
      index       = mod(index-1 + direction, numel(values)) + 1;
      next        = values(index);
    end
  end
  
end
