classdef Responsibility < uint32
  
  enumeration
    Nothing(0)
    OnlyTrain(1)
    Transport(2)
    Weigh(3)
    Water(4)
    Train(5)
    Unknown(inf)
  end
  
  methods (Static)
    function value = default()
      value   = Responsibility.Unknown;
    end
    
    function values = all()
      values  = setdiff(enumeration('Responsibility'), Responsibility.default());
    end
    
    function values = selectable()
      values  = enumeration('Responsibility');
    end
    
    function rgb = color(value)
      switch value
        case Responsibility.Transport;    rgb = [255 237 186]/255;
        case Responsibility.Weigh;        rgb = [222 179 255]/255;
        case Responsibility.Train;        rgb = [208 242 167]/255;
        case Responsibility.Water;        rgb = [166 215 255]/255;
        otherwise;                        rgb = [255 158 158]/255;
      end
    end
  end
  
end
