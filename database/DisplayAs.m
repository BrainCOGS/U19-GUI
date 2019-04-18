classdef DisplayAs < uint32
  
  enumeration
    Row(1)
    Col(2)
    Color(3)
    None(inf)
  end
  
  methods (Static)
    function value = default()
      value   = DisplayAs.Unknown;
    end
    
    function values = all()
      values  = setdiff(enumeration('DisplayAs'), DisplayAs.None);
    end
    
    function values = selectable()
      values  = enumeration('DisplayAs');
    end
    
    function rgb = color(value)
      switch value
        case DisplayAs.Row;     rgb   = [0 189 47]/255;
        case DisplayAs.Col;     rgb   = [0 168 224]/255;
        case DisplayAs.Color;   rgb   = [224 105 0]/255;
        otherwise;              rgb   = [1 1 1]*0.5;
      end
    end
    
    function rgb = background(value)
      rgb = [1 1 1]*0.97;
    end
    
    function str = html(value)
      str = char(value);
    end
    
    function next = cycle(value, direction)
      if nargin < 1
        direction = 1;
      end
      
      values      = enumeration('DisplayAs');
      index       = find(values == value);
      if isempty(index)
        error('DisplayAs:cycle', 'value must be a DisplayAs enumerated type.');
      end
      
      index       = mod(index-1 + direction, numel(values)) + 1;
      next        = values(index);
    end
  end
  
end
