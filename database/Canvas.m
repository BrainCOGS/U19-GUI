%  CANVAS    Embeddable panel for simple painting
% 
% This software depends on the GUI Layout Toolbox:
%   http://www.mathworks.com/matlabcentral/fileexchange/47982-gui-layout-toolbox
% Make sure to get the version appropriate for your version of Matlab (R2014b onwards vs. older).
%
% Author:  Sue Ann Koay (koay@princeton.edu)
%
classdef Canvas < uix.HBox
  
  %------- Constants
  properties (Constant)
    GUI_FONT              = 11
    GUI_BTNSIZE           = 20
    GUI_BORDER            = 5

    CLR_GUI               = [1 1 1]*0.97
    CLR_BUTTON            = [1 1 1]*0.97
    CLR_PALETTE           = designPalette()

    PTR_SIZE              = 16
    BRUSH_SIZE            = [1 16]

    DIR_ICONS             = fullfile(fileparts(mfilename('fullpath')), 'images')
    
    ICON_BRUSH            = zeros(3,3,3)
    ICON_ACCEPT           = Canvas.loadButtonIcon(fullfile(Canvas.DIR_ICONS, 'check.png' ), Canvas.CLR_GUI);
    ICON_CANCEL           = Canvas.loadButtonIcon(fullfile(Canvas.DIR_ICONS, 'cancel.png'), Canvas.CLR_GUI);
  end
  
  %------- Private data
  properties (Access = protected)
    axsPal
    imgPal
    hDrawing      = gobjects(0)
    cnt           = struct()
    btn           = struct()
    brushSize     = 5
    brushColor    = [0 0 0]
    bkgColor
  end
  
  %------- Public data
  properties (SetAccess = protected)
    bitmap
    fig
    axs
    img
    fcnCommit     = []
  end
  
  %________________________________________________________________________
  methods (Static)
    
    function icon = loadButtonIcon(imgFile, bkgColor)
      icon    = imread(imgFile, 'BackgroundColor', bkgColor);
      padding = round(0.25 * size(icon));
      thicker = round(0.07 * size(icon));
      icon    = padarray(icon, padding(1:2), bkgColor(1)*255, 'both');
      icon    = imerode(icon, strel('disk',min(thicker(1:2))));
      icon    = imresize(icon, [1 1]*Canvas.GUI_BTNSIZE);
    end
    
  end
  
  %________________________________________________________________________
  methods

    %----- Constructor
    function obj = Canvas(dimensions, parent, compact, bkgColor, varargin)
      
      %% Default arguments and parent class constructor
      if nargin < 2 || isempty(parent)
        parent          = figure;
      end
      if nargin < 3 || isempty(compact)
        compact         = true;
      end
      if nargin < 4 || isempty(bkgColor)
        bkgColor        = [1 1 1];
      end
      obj@uix.HBox( 'Parent', parent, varargin{:} );
      set(obj, 'Visible', 'off');
      
      %% Special case for starting with an initial image
      if ndims(dimensions) == 3
        obj.bitmap      = dimensions;
      else
        obj.bitmap      = repmat(reshape(bkgColor,1,1,3), dimensions(1), dimensions(2), 1);
      end
      
      %% Create drawing area
      obj.bkgColor      = bkgColor;
      obj.axs           = axes      ( 'Parent'                  , obj                                           ...
                                    , 'ActivePositionProperty'  , 'Position'                                    ...
                                    , 'Box'                     , 'on'                                          ...
                                    , 'Layer'                   , 'top'                                         ...
                                    , 'XTick'                   , []                                            ...
                                    , 'YTick'                   , []                                            ...
                                    , 'XLim'                    , 0.5 + [0, size(obj.bitmap,2)]                 ...
                                    , 'YLim'                    , 0.5 + [0, size(obj.bitmap,1)]                 ...
                                    );
      obj.img           = image     ( 'Parent'                  , obj.axs                                       ...
                                    , 'CData'                   , obj.bitmap                                    ...
                                    , 'CDataMapping'            , 'direct'                                      ...
                                    );
      hold(obj.axs, 'on');
      
      %% Create drawing tools
      obj.cnt.control   = uix.VBox  ( 'Parent'                  , obj                                           ...
                                    , 'BackgroundColor'         , get(obj,'BackgroundColor')                    ...
                                    );
      obj.btn.accept    = uicontrol ( 'Parent'                  , obj.cnt.control                               ...
                                    , 'Style'                   , 'togglebutton'                                ...
                                    , 'CData'                   , Canvas.ICON_ACCEPT                            ...
                                    , 'BackgroundColor'         , Canvas.CLR_BUTTON                             ...
                                    , 'TooltipString'           , '<html><div style="font-size:14px">Accept changes</div></html>'                              ...
                                    , 'Callback'                , @obj.applyEdits                               ...
                                    );
      if compact
        obj.btn.brush   = gobjects(0);
      else
        obj.btn.brush   = uicontrol ( 'Parent'                  , obj.cnt.control                               ...
                                    , 'Style'                   , 'pushbutton'                                  ...
                                    , 'CData'                   , Canvas.ICON_BRUSH                             ...
                                    , 'BackgroundColor'         , Canvas.CLR_BUTTON                             ...
                                    , 'TooltipString'           , '<html><div style="font-size:14px">Select brush</div></html>'                                ...
                                    );
      end
      obj.axsPal        = axes      ( 'Parent'                  , obj.cnt.control                               ...
                                    , 'ActivePositionProperty'  , 'Position'                                    ...
                                    , 'Box'                     , 'on'                                          ...
                                    , 'Layer'                   , 'top'                                         ...
                                    , 'XTick'                   , []                                            ...
                                    , 'YTick'                   , []                                            ...
                                    );
      obj.imgPal        = image     ( 'Parent'                  , obj.axsPal                                    ...
                                    , 'CData'                   , Canvas.CLR_PALETTE                            ...
                                    , 'CDataMapping'            , 'direct'                                      ...
                                    , 'ButtonDownFcn'           , @obj.startEditMode                            ...
                                    );
      obj.btn.cancel    = uicontrol ( 'Parent'                  , obj.cnt.control                               ...
                                    , 'Style'                   , 'togglebutton'                                ...
                                    , 'CData'                   , Canvas.ICON_CANCEL                            ...
                                    , 'BackgroundColor'         , Canvas.CLR_BUTTON                             ...
                                    , 'TooltipString'           , '<html><div style="font-size:14px">Discard changes / right-click clears image</div></html>'  ...
                                    , 'Callback'                , @obj.cancelEditMode                           ...
                                    , 'ButtonDownFcn'           , @obj.clearCanvas                              ...
                                    );
                                  
      %% Configure formatting and sizes
      axis( obj.axs, 'image', 'ij' );
      axis( obj.axsPal, 'tight');
      if compact
        set( obj.cnt.control, 'Heights', [1 -1 1] * Canvas.GUI_BTNSIZE );
      else
        set( obj.cnt.control, 'Heights', [1 1 -1 1] * Canvas.GUI_BTNSIZE );
      end
      set( obj, 'Widths' , [-1, 1.5*Canvas.GUI_BTNSIZE] );
      
      %% Locate parent figure
      obj.fig           = parent;
      while ~isempty(obj.fig) && ~strcmp(get(obj.fig,'Type'), 'figure')
        obj.fig         = get(obj.fig, 'Parent');
      end
      
      %% Java-based formatting
%       drawnow;
%       for name = fieldnames(obj.btn)'
%         if ishghandle(obj.btn.(name{:}))
%           jObject       = findjobj(obj.btn.(name{:}));
%           jObject.setBorder(javax.swing.border.EmptyBorder(1,1,1,1));
%           set(obj.btn.(name{:}), 'Visible', 'off');
%         end
%       end
%       set(obj, 'Visible', 'on');
%                      
    end
    
    %----- Destructor
    function delete(obj)
      delete@uix.HBox(obj);
    end
    
    
    %----- Set the current image, erasing all edits
    function setImage(obj, img)
      obj.cancelEditMode();
      obj.bitmap      = img;
      set(obj.img, 'CData', img);
    end
    
    %----- Set a callback function for when the user accepts changes
    function setCommitCallback(obj, fcn)
      obj.fcnCommit = fcn;
    end
    
    
    %----- Callback to enter a mode where one can draw on the canvas
    function startEditMode(obj, handle, event)
      %% Create a binary mask proportional to the brush size
      width   = (obj.brushSize - Canvas.BRUSH_SIZE(1)) / diff(Canvas.BRUSH_SIZE);
      width   = 1 + round( width * Canvas.PTR_SIZE );
      brush   = strel('square', max(1, min(Canvas.PTR_SIZE, width)));
      brush   = brush.getnhood;
      
      %% Set the mouse pointer shape to look like the brush
      pointer = nan(Canvas.PTR_SIZE);
      pointer(1:size(brush,1), 1:size(brush,2))   ...
              = brush;
      pointer(pointer == 0) = nan;
      set(obj.fig, 'Pointer', 'custom', 'PointerShapeCData', pointer, 'PointerShapeHotSpot', ceil(size(brush)/2));
      
      %% Make edit controls visible and allow color selection
      set([obj.btn.accept, obj.btn.brush, obj.btn.cancel], 'Visible', 'on', 'Enable', 'on');
      set(handle, 'ButtonDownFcn', @obj.setBrushColor);
      obj.setBrushColor(handle, event);

      %% Set callbacks for drawing functionality
      set ( obj.fig                                                     ...
          , 'WindowButtonDownFcn'       , @obj.startDraw                ...
          , 'WindowButtonMotionFcn'     , @obj.continueDraw             ...
          , 'WindowButtonUpFcn'         , @obj.stopDraw                 ...
          );
    end
    
    %----- Callback to cancel editing mode, discarding changes
    function cancelEditMode(obj, handle, event)
      set(obj.fig, 'Pointer', 'arrow', 'WindowButtonDownFcn', '', 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
      delete(obj.hDrawing);
      obj.hDrawing      = gobjects(0);
      set([obj.btn.accept, obj.btn.brush, obj.btn.cancel], 'Visible', 'off', 'Enable', 'off');
      set(obj.img, 'CData', obj.bitmap);
      set(obj.imgPal, 'ButtonDownFcn', @obj.startEditMode);
    end
    
    %----- Callback to clear the canvas
    function clearCanvas(obj, handle, event)
      delete(obj.hDrawing);
      obj.hDrawing      = gobjects(0);
      set(obj.img, 'CData', repmat(reshape(obj.bkgColor,1,1,3), size(obj.bitmap,1), size(obj.bitmap,2), 1));
    end
    
  end
  

  %________________________________________________________________________
  methods (Access = protected)
    
    %----- Callback to apply changes and end edit mode
    function applyEdits(obj, handle, event)
      %% Copy everything to a temporary figure because getframe() is tricky for some OS/Matlab versions
      copySize    = get(obj.axs, 'Position');
      figCopy     = figure('Units', 'pixels', 'Position', [100, 100, 1+copySize(3:4)], 'Visible', 'off');
      axsCopy     = axes( 'Parent'        , figCopy                       ...
                        , 'Units'         , 'pixels'                      ...
                        , 'Position'      , [1 1 copySize(3:4)]           ...
                        , 'XLim'          , get(obj.axs,'XLim')           ...
                        , 'YLim'          , get(obj.axs,'YLim')           ...
                        , 'YDir'          , get(obj.axs,'YDir')           ...
                        , 'XColor'        , 'none'                        ...
                        , 'YColor'        , 'none'                        ...
                        );

      copyobj(obj.img, axsCopy);
      for iLine = 1:numel(obj.hDrawing)
        copyobj(obj.hDrawing(iLine), axsCopy);
      end
      drawnow;
      
      %% Use frame capture and downsample to the target bitmap
      targetSize  = size(obj.bitmap);
      frame       = getframe(axsCopy);
      frame       = imresize(frame.cdata, targetSize(1:2));
      obj.bitmap  = frame;
      
      %% Update image and exit editing mode
      delete(figCopy);
      set(obj.img, 'CData', obj.bitmap);
      obj.cancelEditMode(handle, event);
      
      if ~isempty(obj.fcnCommit)
        if iscell(obj.fcnCommit)
          obj.fcnCommit{1}(obj.fcnCommit{2:end}, obj.bitmap);
        else
          obj.fcnCommit(obj.bitmap);
        end
      end
    end
    
    
    %----- Callback to set the brush color
    function setBrushColor(obj, handle, event)
      clickPoint        = get(obj.axsPal, 'CurrentPoint');
      rowColor          = round(clickPoint(1,2));
      colColor          = round(clickPoint(1,1));
      obj.brushColor    = Canvas.CLR_PALETTE(max(1,min(end,rowColor)), max(1,min(end,colColor)), :);
      if ~isempty(obj.btn.brush)
        set(obj.btn.brush, 'CData', repmat(obj.brushColor, obj.brushSize, obj.brushSize, 1));
      end
      
      set(obj.axs, 'XColor', obj.brushColor, 'YColor', obj.brushColor, 'LineWidth', 5);
      drawnow;
      pause(0.3);
      set(obj.axs, 'XColor', [1 1 1]*0.15, 'YColor', [1 1 1]*0.15, 'LineWidth', 0.5);
      drawnow;
    end
    
    
    %----- Callback to start drawing
    function startDraw(obj, handle, event)
      set(handle, 'UserData', true);
      obj.hDrawing(end+1) = line( 'Parent'                  , obj.axs                           ...
                                , 'XData'                   , []                                ...
                                , 'YData'                   , []                                ...
                                , 'LineWidth'               , obj.brushSize                     ...
                                , 'Color'                   , obj.brushColor                    ...
                                );
    end
    
    %----- Callback to stop drawing
    function stopDraw(obj, handle, event)
      set(handle, 'UserData', false);
    end
    
    %----- Callback to add points to the currently drawn line
    function continueDraw(obj, handle, event)
      if ~isequal(get(handle, 'UserData'), true)
        return;
      end
      
      %% Restrict new point to available drawing area
      newPoint        = get(obj.axs, 'CurrentPoint');
      newPoint        = newPoint(1,1:2);
      newPoint(1)     = max(1, min(newPoint(1), size(obj.bitmap,2)));
      newPoint(2)     = max(1, min(newPoint(2), size(obj.bitmap,1)));
      
      %% Add point to current line
      xData           = get(obj.hDrawing(end), 'XData');
      yData           = get(obj.hDrawing(end), 'YData');
      set(obj.hDrawing(end), 'XData', [xData, newPoint(1)], 'YData', [yData, newPoint(2)]);
    end
    
  end
  
end
