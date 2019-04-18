classdef HandlingStatus < uint32
  
  enumeration
    Unknown(0)
    InExperiments(1)
    WaterRestrictionOnly(2)
    Missing(3)
    AdLibWater(4)
    Dead(5)
  end
  
  methods (Static)
    function value = default()
      value   = HandlingStatus.Unknown;
    end
    
    function values = all()
      values  = setdiff(enumeration('HandlingStatus'), HandlingStatus.default());
    end
    
    function values = selectable()
      values  = setdiff(enumeration('HandlingStatus'), [HandlingStatus.Missing, HandlingStatus.Dead]);
    end
    
    function rgb = color(value)
      switch value
        case HandlingStatus.InExperiments;          rgb = [222 179 255]/255;
        case HandlingStatus.WaterRestrictionOnly;   rgb = [166 215 255]/255;
        case HandlingStatus.Missing;                rgb = [255 158 158]/255;
        case HandlingStatus.AdLibWater;             rgb = [1 1 1]*0.94;
        case HandlingStatus.Dead;                   rgb = [181 181 181]/255;
        otherwise;                                  rgb = [255 239 168]/255;
      end
    end
  end
  
end
