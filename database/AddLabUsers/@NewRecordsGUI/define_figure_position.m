function [position] = define_figure_position(~, position)
%Define the figure position and make correspondant transformation
%
% Inputs:
% position = Initial position coordentates for GUI figure
% Outputs:
% position = Final position coordentates after doing transformations

  % Get the screen coordinates to reference the figure position against
  screenSize          = get(0, 'MonitorPosition');
  
  % Convert position to relative coordinate if necessary
  position(1:2)       = standardCoordinate(position(1:2), screenSize(3:4)) + screenSize(1:2);
  position(3:4)       = standardCoordinate(position(3:4), screenSize(3:4));
  
end

function coordinate = standardCoordinate(coordinate, range)
% Convert position to relative coordinate if necessary


  for iCoord = 1:numel(coordinate)
    if coordinate(iCoord) < 0
      coordinate(iCoord)  = range(iCoord) + coordinate(iCoord)+1;
    elseif abs(coordinate(iCoord)) <= 1
      coordinate(iCoord)  = range(iCoord) * coordinate(iCoord);
    end
  end
  coordinate(isnan(coordinate)) = min(coordinate, [], 'omitnan');

end
