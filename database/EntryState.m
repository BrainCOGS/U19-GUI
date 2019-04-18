classdef EntryState < uint32
  
  enumeration
    Invalid(0)
    Valid(1)
    Suggested(2)
    Freeform(3)
    DisplayOnly(4)
    Unknown(inf)
  end
  
  methods (Static)
    function value = default()
      value   = EntryState.Unknown;
    end
    
    function values = all()
      values  = setdiff(enumeration('EntryState'), EntryState.default());
    end
    
    function rgb = color(value)
      switch value
        case EntryState.Invalid;        rgb = [255 219 219]/255;
        case EntryState.Valid;          rgb = [1 1 1];
        case EntryState.Suggested;      rgb = [255 246 186]/255;
        case EntryState.Freeform;       rgb = [1 1 1];
        case EntryState.DisplayOnly;    rgb = [1 1 1]*0.97;
        otherwise;                      rgb = [0 0 0]*0.6;
      end
    end
  end
  
end
