classdef Sex < uint32
  
  enumeration
    Male(1)
    Female(2)
    Unknown(inf)
  end
  
  methods (Static)
    function value = default()
      value   = Sex.Unknown;
    end
    
    function values = all()
      values  = setdiff(enumeration('Sex'), Sex.default());
    end
    
    function values = selectable()
      values  = enumeration('Sex');
    end
    
    function rgb = color(value)
      rgb     = [0 0 0];
    end
  end
  
end
