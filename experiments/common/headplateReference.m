function headplateReference

global obj

%% start GUI and draw buttons
drawGUIfig; % nested function at the bottom

%% start webcam
obj                  = createWebcamObj(obj);
obj.savepathroot     = 'C:\Data\headplateRef\';
obj.headplateOutline = [];

end

%% camera on/off
function camON_callback(~,event)
global obj

if get(obj.camON,'Value') == true 
  
  % create video input
  if ~isfield(obj,'vid'); obj = createWebcamObj(obj); end
  
  % go into video data acquisition loop
  try
      camLoop;
  catch 
      delete(obj.vid)
      obj = createWebcamObj(obj);
      camLoop;
  end

else
  delete(obj.vid)
  obj = createWebcamObj(obj);
end
end

%% subject
% select mouse
function subjList_callback(~,event)

global obj 

obj.mouseID  = get(obj.subjList,'String');
obj.savepath = sprintf('%s%s\\',obj.savepathroot,obj.mouseID);

% create directory for animal if necessary
if isempty(dir(obj.savepath))
  mkdir(obj.savepath);
end

% load reference image
if ~isempty(dir(sprintf('%s%s_refIm.mat',obj.savepath,obj.mouseID)))
  load(sprintf('%s%s_refIm',obj.savepath,obj.mouseID),'frame')
  obj.refIm  = frame;
else
  warndlg('reference image not found')
end

% load headplate outline
if ~isempty(dir(sprintf('%s%s_headplate.mat',obj.savepath,obj.mouseID)))
  load(sprintf('%s%s_headplate.mat',obj.savepath,obj.mouseID),'headplateContour')
  obj.headplateOutline = headplateContour;
else
  warndlg('headplate outline not found')
end

end

%% save frame
function grabFrame_callback(~,event)
global obj 
if get(obj.grab,'Value') == true
  
  set(obj.camON,'Value',false);
  drawnow();
  camON_callback([],1);
  
  
  uin = questdlg('save as reference image?'); % save?
  switch uin
    case 'Yes'
      thisfn = sprintf('%s%s_refIm',obj.savepath,obj.mouseID);
      obj.refIm = obj.camData;
      
      % save as refIM and also with a date for recordkeeping
      frame = obj.camData; 
      save(thisfn,'frame')
      imwrite(frame,sprintf('%s.tif',thisfn),'tif')
      
      % reset im registration
      obj.imTform = [];
      
    case 'No'
      thisls = dir(sprintf('%s%s_frameGrab*',obj.savepath,obj.fn));
      if isempty(thisls)
        thisfn = sprintf('%s%s_frameGrab',obj.savepath,obj.fn);
      else
        thisfn = sprintf('%s%s_frameGrab-%d',obj.savepath,obj.fn,length(thisls));
      end
      obj.currIm = obj.camData;
      
      frame = obj.camData; 
      save(thisfn,'frame')
      imwrite(frame,sprintf('%s.tif',thisfn),'tif')
    case 'Cancel'
      close(f1)
  end
  
%   set(f1,'visible','on','position',[20 20 obj.vidRes]);
%   close(f1)
%   fprintf('image saved to %s\n',thisfn)
  
  % prompt to register
  if strcmpi(uin,'No')
    uin3 = questdlg('register to reference image?');
    if strcmpi(uin3,'Yes')
      set(obj.registerIm,'Value',true)
      registerIm_callback([],1);
      set(obj.registerIm,'Value',false)
    end
  end
  plotHeadplateOutline(obj.camfig);
end
end

%% draw headplate outline
function drawHeadplate_callback(~,event)
global obj 

if get(obj.drawHeadplate,'Value') == true
  % manually draw headplate
  drawHeadplate(obj.savepath,obj.mouseID)
  
  % plot it
  plotHeadplateOutline(obj.camfig);
end

end

%% 
% register iamge
function registerIm_callback(~,event)
global obj 

if get(obj.registerIm,'Value') == true
  
  if isempty(obj.currIm)
    thisdir = pwd;
    cd(obj.savepath)
    thisfn = uigetfile('*.tif','select image');
    frame = imread(thisfn);
    cd(thisdir)
    obj.currIm  = obj.camData; %double(frame);
%     obj.camData = frame;
  end
  
  set(obj.statusTxt,'String','performing Im regsitration...')
  drawnow()
  
  [regMsg,obj.okFlag] = registerImage(obj.refIm,obj.currIm,false);
  wd = warndlg(regMsg,'Registration output');
end

end

%% reset
function reset_callback(~,event)
global obj 
if get(obj.resetgui,'Value') == true
  delete(obj.vid)
  close(obj.fig); clear
  headplateReference;
end
end

%% quit GUI
function quitgui_callback(~,event)
global obj 
if get(obj.quitgui,'Value') == true
  delete(obj.vid)
  close(obj.fig); clear
end
end

%% set directory for file saving
function cd_callback(~,event)
global obj 
if event == true || get(obj.sdir,'Value') == true
  obj.savepathroot = uigetdir(pwd,'Pick a directory');
end
end

%% image acquisition loop
function camLoop
warning off

global obj

stopL   = false; 
vidRate = 10;

axes(obj.camfig)

% timing here is not strictly enforced, roughly 20 Hz
while ~ stopL
    tic;
    
    % get cam data 
    delay(0.001);
    dataRead    = snapshot(obj.vid);
    obj.camData = dataRead(:,:,:,end);
    if isempty(dataRead); continue; else clear dataRead; end
    
    % plot
    plotHeadplateOutline(obj.camfig)
    
    % check for other stuff in gui and roughly enforce timing
    drawnow()
    if get(obj.camON,'Value') == false; stopL = true; end
    if toc < 1/vidRate; delay(1/vidRate-toc); end
end

delete(obj.vid);

warning on

end

%% plot outline of headplate
function plotHeadplateOutline(fh)

global obj

if nargin < 1
    fh = [];
end
if isempty(fh)
axes(obj.camfig); % focus
cla
end

imshow(obj.camData); %colormap gray;  
set(gca,'xtick',[],'ytick',[]);

% headplate
if ~isempty(obj.headplateOutline)
  hold(obj.camfig,'on')
  [y,x] = find(obj.headplateOutline==1);
  plot(x,y,'y.')
  axis image;
end
end

%% create cam object 
function obj = createWebcamObj(obj)

if isprop(RigParameters,'webcam_name')
  obj.vid                 = webcam(RigParameters.webcam_name);
else
  obj.vid                 = webcam;
end
obj.vidRes(1)             = str2double(obj.vid.Resolution(1:3));
obj.vidRes(2)             = str2double(obj.vid.Resolution(5:7));
obj.hImage                = image(zeros(obj.vidRes(1),obj.vidRes(2),3),'Parent',obj.camfig);
set(obj.camfig,'visible','on'); axis off

if isprop(RigParameters,'webcam_zoom')
  set(obj.vid,'Zoom',RigParameters.webcam_zoom)
end
if isprop(RigParameters,'webcam_focus')
  set(obj.vid,'Focus',RigParameters.webcam_focus)
end

end

%% draw headlate outline
function drawHeadplate(impath,mouseID)

refpath = dir([impath '*refIm.mat']);
load([impath refpath.name],'frame')

fh = figure;
imshow(frame)
headplate        = roipoly;
headplateContour = bwperim(headplate);
close(fh)

save([impath mouseID '_headplate.mat'],'headplateContour','headplate')
end

%% delay (more precise than delay
function t = delay(seconds)
% function pause the program
% seconds = delay time in seconds
tic; t=0;
while t < seconds
    t=toc;
end
end

% =========================================================================
%% DRAW GUI OBJECT
function drawGUIfig

global obj

% create GUI figure
ss = get(groot,'screensize');
ss = ss(3:4);
obj.fig    =   figure    ('Name',               'Headplate reference',     ...
                          'NumberTitle',        'off',                     ...
                          'Position',           round([ss(1)*.18 ss(2)*.26 ss(1)*.64 ss(2)*.48]));
                        

%% cam display
obj.camfig  =   axes      ('units',             'normalized',       ...
                        'position',             [.02 .16 .96 .8],   ...
                        'parent',               obj.fig,            ...
                        'visible',              'off',              ...
                        'xtick',                [],                 ...
                        'ytick',                []);

%% buttons                      
obj.subjtxt   =   uicontrol (obj.fig,                               ...
                        'Style',                'text',             ...
                        'String',               'Mouse ID:',        ...
                        'Units',                'normalized',       ...
                        'Position',             [.02 .025 .12 .07],  ...
                        'horizontalAlignment',  'left',             ...
                        'fontsize',             13,                 ...
                        'fontweight',           'bold');
obj.subjList =   uicontrol (obj.fig,                            ...
                        'Style',                'edit',             ...
                        'Units',                'normalized',       ...
                        'Position',             [.14 .02 .1 .07],  ...
                        'horizontalAlignment',  'left',             ...
                        'fontsize',             13,                 ...
                        'Callback',             @subjList_callback);
obj.quitgui =   uicontrol (obj.fig,                                 ...
                        'String',               'QUIT',             ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.91 .02 .07 .07],  ...
                        'foregroundColor',      [1 0 0],            ...
                        'Callback',             @quitgui_callback,  ...
                        'fontsize',             13,                 ...
                        'fontweight',           'bold'); 
obj.resetgui   =   uicontrol (obj.fig,                              ...
                        'String',               'RESET',            ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.84 .02 .07 .07],  ...
                        'Callback',             @reset_callback,    ...
                        'fontsize',             13,                 ...
                        'foregroundColor',      [1 .6 .1],          ...
                        'fontweight',           'bold');
obj.camON   =   uicontrol (obj.fig,                                 ...
                        'String',               'cam ON',           ...
                        'Style',                'togglebutton',     ...
                        'Units',                'normalized',       ...
                        'Position',             [.32 .02 .12 .07],   ...
                        'Callback',              @camON_callback,   ...
                        'fontsize',             13);
obj.grab    =   uicontrol (obj.fig,                                 ...
                        'String',               'grab frame',       ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.44 .02 .12 .07],   ...
                        'Callback',             @grabFrame_callback,...
                        'fontsize',             13); 
obj.registerIm    =   uicontrol (obj.fig,                           ...
                        'String',               'register',         ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.56 .02 .12 .07],    ...
                        'Callback',             @registerIm_callback,...
                        'fontsize',             13); 
obj.drawHeadplate =   uicontrol (obj.fig,                           ...
                        'String',               'draw plate' ,      ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.68 .02 .12 .07],   ...
                        'Callback',             @drawHeadplate_callback,  ...
                        'fontsize',             12);
obj.sdir   =   uicontrol (obj.fig,                                  ...
                        'String',               'set dir',          ...
                        'Style',                'pushbutton',       ...
                        'Units',                'normalized',       ...
                        'Position',             [.25 .02 .07 .07],  ...
                        'Callback',             @cd_callback,       ...
                        'fontsize',             13,                 ...
                        'fontweight',           'bold');
                      
end