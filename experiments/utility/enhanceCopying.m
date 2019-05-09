%%
%
function [varargout] = enhanceCopying(handles, copyWholeFigure)

  %-----  Get axis handles if none are provided
  if nargin < 1
    handles       = vca;
  end
  if nargin < 2
    copyWholeFigure = true;
  end
  
  
  %-----  Available context menus
  if copyWholeFigure
    menuSpecs     = { {'Copy figure' }   ...
                    };
  else
    menuSpecs     = { {'Copy with negative borders' , 'position', 'OuterPosition', 'units', 'pixels'    , 'border', [-9   -6  ], 'includePeers', true , 'scaleFactor', 1} ...
                    , {'Copy with tight borders'    , 'position', 'OuterPosition', 'units', 'pixels'    , 'border', [1    1   ], 'includePeers', true , 'scaleFactor', 1} ...
                    , {'Copy with loose borders'    , 'position', 'OuterPosition', 'units', 'pixels'    , 'border', [10   10  ], 'includePeers', true , 'scaleFactor', 1} ...
                    , {'Copy x2 size'               , 'position', 'OuterPosition', 'units', 'pixels'    , 'border', [10   10  ], 'includePeers', true , 'scaleFactor', 2} ...
                    , {'Copy plot area'             , 'position', 'Position'     , 'units', 'pixels'    , 'border', [1    1   ], 'includePeers', false, 'scaleFactor', 1} ...
                    , {'Copy plot area + 5% border' , 'position', 'Position'     , 'units', 'normalized', 'border', [0.05 0.05], 'includePeers', false, 'scaleFactor', 1} ...
                    , {'Copy plot area + 10% border', 'position', 'Position'     , 'units', 'normalized', 'border', [0.1  0.1 ], 'includePeers', false, 'scaleFactor', 1} ...
                    , {'Copy plot area + 20% border', 'position', 'Position'     , 'units', 'normalized', 'border', [0.2  0.2 ], 'includePeers', false, 'scaleFactor', 1} ...
                    , {'Copy x2 plot area'          , 'position', 'Position'     , 'units', 'pixels'    , 'border', [1    1   ], 'includePeers', false, 'scaleFactor', 2} ...
                    , {'Copy entire figure'}                                                                                                                              ...
                    };
  end
  
  
  %-----  Find all axes if given figure handles
  handles         = colvec(handles(isgraphics(handles)));
  for iHandle = numel(handles):-1:1
    if strcmpi(get(handles(iHandle), 'Type'), 'figure')
      handles     = [ handles(1:iHandle-1)                      ...
                    ; findall(handles(iHandle), 'Type', 'axes') ...
                    ; handles(iHandle+1:end)                    ...
                    ];
    end
  end
  
  
  %-----  Loop through axes
  currentFig      = get(0, 'CurrentFigure');
  for handle = rowvec(handles)
    % Obtain figure handle
    hFigure       = findParent(handle, 'figure');
    if ~strcmpi(get(hFigure, 'Type'), 'figure')
      continue;
    end
    
    % Setup a context menu
    set(0, 'CurrentFigure', hFigure);
    hcmenu        = uicontextmenu;
    
    for iMenu = 1:numel(menuSpecs)
      % Construct user data for what to do
      menuData    = struct(menuSpecs{iMenu}{2:end});
      if numel(menuSpecs{iMenu}) == 1
        menuData.handle = hFigure;
      else
        menuData.handle = handle;
      end

      menuItem    = uimenu( hcmenu                          ...
                          , 'Label'   , menuSpecs{iMenu}{1} ...
                          , 'Callback', @plotCopyCallback   ...
                          , 'UserData', menuData            ...
                          );
                        
      % Set context menu for everything with area
      hAreas      = [handle; findall(handle, 'Type', 'axes')];
      hAreas      = [hAreas; findall(handle, 'Type', 'patch')   ...
                           ; findall(handle, 'Type', 'text')    ...
                           ; findall(handle, 'Type', 'line')    ...
                    ];
      set(hAreas, 'uicontextmenu', hcmenu);
    end
  end
  

  %-----  Output on demand
  if ~isempty(currentFig)
    set(0, 'CurrentFigure', currentFig);
  end
  
  if nargout > 0
    varargout   = {handles};
  end
  
end

function plotCopyCallback(varargin)

  % Special case to copy entire figure
  data              = get(varargin{1}, 'UserData');
  if strcmpi(get(data.handle, 'Type'), 'figure')
    print(data.handle, '-dmeta');    
    return;
  end

  % Locate all associated axes
  assocHandles      = findAssociates(data.handle, 'legend'  );
  if data.includePeers
    regionHandles   = findAssociates(data.handle, 'Colorbar');
    regionHandles   = [data.handle, regionHandles{:}];
  else
    regionHandles   = data.handle;
  end
  
  % The total position includes all peers
  plotRegion        = [inf inf -inf -inf];
  for iPeer = 1:numel(regionHandles)
    position        = rget(regionHandles(iPeer), data.position, 'Units', 'pixels');
    region          = [position(1:2), position(1:2) + position(3:4)];
    plotRegion      = [ min(plotRegion(1:2), region(1:2))   ...
                      , max(plotRegion(3:4), region(3:4))   ...
                      ];
  end
  origPos           = [plotRegion(1:2), plotRegion(3:4) - plotRegion(1:2)];
  
  % In case of relative units, compute the border (l,b,r,t) in pixels
  if strcmpi(data.units, 'normalized')
    border          = origPos(3:4) .* data.border;
  else
    border          = data.border;
  end
  border            = repmat(colvec(border), 1, 2);
  
  % HACK : Extra space required for z axis
  if numel(regionHandles) > 1
    border(3)       = 1.5*border(3) + 8;
  end
  
  % Construct a temporary figure for copying that is just large enough
  copyFig           = figure( 'Visible', 'off'                                ...
                            , 'Units', 'pixels'                               ...
                            , 'Position'                                      ...
                            , [50, 50, data.scaleFactor*origPos(3:4) + rowvec(sum(border,2))]  ...
                            );
  
  % Copy and reposition all associated axes
  copyGraphics([regionHandles, assocHandles{:}], copyFig, data.position, -origPos(1:2) + border(1:2), data.scaleFactor, 'pixels');
%   for handle = [regionHandles, assocHandles{:}]
%     copyGraphics(handle, copyFig, data.position, -origPos(1:2) + border(1:2), data.scaleFactor, 'pixels');
%   end
  
  % Print to clipboard and delete figure
  print(copyFig, '-dmeta');
  delete(copyFig);

end
