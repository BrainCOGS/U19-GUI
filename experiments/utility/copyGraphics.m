function [copyHandle] = copyGraphics(sourceHandle, targetHandle, positionType, offset, scaleFactor, units)
% COPYGRAPHICS    Copies a graphical object with smarter preservation of
%                 properties.

  %-----  Basic copy function
  copyHandle        = copyobj(sourceHandle, targetHandle);

  for iObj = 1:numel(sourceHandle)
    objHandle       = sourceHandle(iObj);

    origUnits       = get(objHandle, 'Units');
    set ( objHandle , 'Units', units );
    set ( copyHandle(iObj), 'Units', units );


    %----- Now apply absolute positioning
    if isprop(objHandle, positionType)
      position      = positionType;
      origPos       = get(objHandle, position);
      set ( copyHandle(iObj)                                  ...
          , 'ActivePositionProperty'                          ...
          , get(objHandle, 'ActivePositionProperty')          ...
          , position, [origPos(1:2) + offset, scaleFactor*origPos(3:4)]   ...
          );  
    else
      position      = 'Position';
      origPos       = get(objHandle, position);
      set ( copyHandle(iObj)                                  ...
          , position, [origPos(1:2) + offset, scaleFactor*origPos(3:4)]   ...
          );  
    end

    %-----  Preserve relative placements (must be done with absolute units)  
    if ~strcmpi(position, 'Position')
      origInner     = get(objHandle, 'Position'     );
      origOuter     = get(objHandle, 'OuterPosition');
      copyPos       = get(copyHandle(iObj), 'OuterPosition');
      set ( copyHandle(iObj), 'Position'    ...
          , copyPos + origInner-origOuter   ...
          );
    end

    % OMG OMG OMG Matlab shuffles this after setting Position
  %   copyPos         = get(copyHandle, 'OuterPosition');


    %-----  Preserve associated objects
    copyTitle       = get(copyHandle(iObj), 'Title');
    origTitle       = get(objHandle , 'Title');
    try
      copyProperty(copyTitle, origTitle, 'Position', 'HorizontalAlignment', 'VerticalAlignment');
    catch
    end

    if strcmp(get(objHandle, 'Type'), 'axes')
      cmap          = colormap(objHandle);
      colormap(copyHandle(iObj), cmap);
    end


    %-----  Reset properties of the original object
    set(objHandle, 'Units', origUnits);
  end
  
end

function [] = copyProperty(copyHandle, origHandle, varargin)

  for iArg = 1:numel(varargin)
    property  = varargin{iArg};
    set( copyHandle, property, get(origHandle, property) );
  end

end

