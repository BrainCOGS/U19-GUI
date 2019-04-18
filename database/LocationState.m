classdef LocationState < uint32
  
  enumeration
    WithYou(1)
    WithAnother(2)
    AtHome(3)
    Everywhere(4)
    Unknown(inf)
  end
  
  methods (Static)
    function value = default()
      value   = LocationState.Unknown;
    end
    
    function values = all()
      values  = setdiff(enumeration('LocationState'), LocationState.default());
    end
    
    function rgb = color(value)
      switch value
        case LocationState.WithYou;         rgb = [222 179 255]/255;
        case LocationState.WithAnother;     rgb = [221 240 197]/255;
        case LocationState.AtHome;          rgb = [1 1 1]*0.88;
        case LocationState.Everywhere;      rgb = [255 224 189]/255;
        otherwise;                          rgb = [255 219 219]/255;
      end
    end
  end
  
end
