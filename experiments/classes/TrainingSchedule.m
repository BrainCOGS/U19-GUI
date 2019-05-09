classdef TrainingSchedule < handle
  
  %________________________________________________________________________
  properties (Constant)
    BUTTON_HEIGHT           = 70
    BUTTON_WIDTH            = 290
    GUI_POSITION            = [-TrainingSchedule.BUTTON_WIDTH - 30, 50, TrainingSchedule.BUTTON_WIDTH + 10, 800]
    FONT_SIZE               = 13

    CLR_TODO                = [0 100 220]/255
%     CLR_DONE                = [122 150 65]/255
    CLR_DONE                = [1 1 1]*0.5
    CLR_SAVED               = [185 232 128]/255
    CLR_DIRTY               = [242 138 138]/255
    BKG_DONE                = [1 1 1]*0.8
    BORDER_HILIGHT          = 4

    REFRESH_PERIOD          = 60*30       % seconds
    PROGRAM_MASK            = fullfile(parsePath(parsePath(which('TrainingSchedule'))), 'programs', '*.m');
    START_DIR               = fileparts(which('startup'));
    MAX_LINE_LENGTH         = 20
  end
  
  properties (SetAccess = protected)
    schedule                % List of programs that call runCohortExperiment, in order to be run for the day
    completed               % Whether the correspondingly indexed program in the schedule has been completed for the day
    regiment                % The currently open TrainingRegiment, if any
  end
  
  properties (SetAccess = protected, Transient)
    scheduleFile            % Disk storage location of schedule
    figGUI                  % Figure for GUI
    
    dayTimer                % For triggering refresh upon change of date
    refDate                 % For checking whether a program has been completed
  end
  
  properties (Access = protected, Transient)
    cnt                     % Containers
    scd                     % Schedule containers
    scb                     % Schedule buttons
    ctrl                    % Other controls
    
    savedOnDisk     = true  % Whether this schedule is as saved on disk
    defaultRestart  = 1     % Whether to default to restarting Matlab after each round
  end
  
  %________________________________________________________________________
  methods
    
    %----- Constructor from a given file in which the schedule is (to be) stored
    function obj = TrainingSchedule(scheduleFile, autoStart)
      %% Default arguments
      if ~exist('scheduleFile', 'var')
        scheduleFile        = fullfile('C:', 'Data', [RigParameters.rig '_schedule.mat']);
      end
      if ~exist('autoStart', 'var')
        autoStart           = [];
      end

      %% Read schedule, if available
      if exist(scheduleFile, 'file')
        thawed              = load(scheduleFile, 'schedule');
        obj                 = thawed.schedule;
      end
      obj.scheduleFile      = scheduleFile;
      
      %% Automatically start GUI and run the given program
      if ~isempty(autoStart)
        obj.gui(false);
        program             = str2func(autoStart);

        set(obj.figGUI, 'Pointer', 'watch');
        program([], [], @obj.fcnCheckSchedule);
      end
    end
    
    %----- Destructor
    function delete(obj)
      
      if ~isempty(obj.dayTimer) && isvalid(obj.dayTimer)
        stop(obj.dayTimer);
        delete(obj.dayTimer);
      end
      delete(obj.figGUI);
      
    end
    
    %----- Structure version to store an object of this class to disk
    function frozen = saveobj(obj)
      %% Store all mutable and non-transient data
      metadata      = metaclass(obj);
      for iProp = 1:numel(metadata.PropertyList)
        property    = metadata.PropertyList(iProp);
        if ~property.Transient && ~property.Constant
          frozen.(property.Name)  = obj.(property.Name);
        end
      end
    end

    %----- Launch GUI with scheduled list of training programs
    function gui(obj, checkSchedule)
      
      %% Default arguments
      if ~exist('checkSchedule', 'var') || isempty(checkSchedule)
        checkSchedule       = true;
      end

      
      %% (Re)create figure
      if ishghandle(obj.figGUI)
        delete(obj.figGUI);
      end
      
      obj.figGUI            = makePositionedFigure(TrainingSchedule.GUI_POSITION, TrainingRegiment.MONITOR, [], 'MenuBar', 'none', 'Toolbar', 'none');
      
      %% Setup timer for detecting date changes
      if ~isempty(obj.dayTimer) && isvalid(obj.dayTimer)
        stop(obj.dayTimer);
        delete(obj.dayTimer);
      end
      
      obj.dayTimer          = timer( 'Name'           , 'valve-check'                       ...
                                   , 'StartDelay'     , 30                                  ...
                                   , 'TimerFcn'       , @obj.fcnCheckSchedule               ...
                                   , 'ExecutionMode'  , 'fixedRate'                         ...
                                   , 'Period'         , TrainingSchedule.REFRESH_PERIOD     ...
                                   );
      
      %% Containers for schedule list and controls
      obj.cnt.main          = uix.VBox('Parent', obj.figGUI, 'Padding', 5, 'Spacing', 10);
      obj.ctrl.day          = uicontrol( 'Parent', obj.cnt.main, 'Style', 'text', 'HorizontalAlignment', 'center', 'String', ''   ...
                                       , 'FontSize', TrainingSchedule.FONT_SIZE );
      obj.cnt.schedule      = uix.VButtonBox( 'Parent', obj.cnt.main, 'ButtonSize', [TrainingSchedule.BUTTON_WIDTH, TrainingSchedule.BUTTON_HEIGHT+5]   ...
                                            , 'Spacing', 5, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top' );
      obj.cnt.control       = uix.VBox('Parent', obj.cnt.main);
      
      %% Controls 
      obj.ctrl.restart      = uicontrol( 'Parent', obj.cnt.control, 'Style', 'checkbox', 'String', 'Restart Matlab before running'        ...
                                       , 'Value', obj.defaultRestart, 'FontSize', TrainingSchedule.FONT_SIZE );
      obj.cnt.control2      = uix.HBox('Parent', obj.cnt.control, 'Spacing', 5);
      obj.ctrl.run          = uicontrol( 'Parent', obj.cnt.control2, 'Style', 'pushbutton', 'String', 'RUN', 'FontWeight', 'bold'         ...
                                       , 'FontSize', TrainingSchedule.FONT_SIZE, 'ForegroundColor', TrainingSchedule.CLR_TODO             ...
                                       , 'TooltipString', 'Run the next scheduled program', 'Callback', @obj.fcnRunNextProgram );
      obj.ctrl.save         = uicontrol( 'Parent', obj.cnt.control2, 'Style', 'pushbutton', 'String', 'Save'                              ...
                                       , 'FontSize', TrainingSchedule.FONT_SIZE, 'Callback', @obj.fcnSaveSchedule                         ...
                                       , 'TooltipString', ['Save schedule to ' obj.scheduleFile] );
      
      %% Layout proportions
      set(obj.cnt.main, 'Heights', [0.5*TrainingSchedule.BUTTON_HEIGHT, -1, 1.5*TrainingSchedule.BUTTON_HEIGHT]);
      
      %% Control for adding an item to the schedule
      obj.scb               = gobjects(0);
      obj.scd               = uix.HBox('Parent', obj.cnt.schedule, 'Spacing', 5);
      uix.Empty('Parent', obj.scd);
      uicontrol( 'Parent', obj.scd, 'Style', 'pushbutton', 'String', '?', 'FontSize', TrainingSchedule.FONT_SIZE+3      ...
               , 'Callback', {@obj.fcnCheckSchedule,true}, 'TooltipString', 'Refresh program completion status' );
      uicontrol( 'Parent', obj.scd, 'Style', 'pushbutton', 'String', '+', 'FontSize', TrainingSchedule.FONT_SIZE+3      ...
               , 'Callback', @obj.fcnAddToSchedule, 'TooltipString', 'Add a program to the schedule' );
      set(obj.scd, 'Widths', [-1, 0.6*TrainingSchedule.BUTTON_HEIGHT, 0.6*TrainingSchedule.BUTTON_HEIGHT]);
      
      %% Add items in schedule
      obj.completed         = cell(size(obj.schedule));
      for iProg = 1:numel(obj.schedule)
        obj.fcnAddToSchedule(obj.schedule{iProg});
      end
      if checkSchedule
        obj.fcnCheckSchedule();
      end
      uicontrol(obj.ctrl.run);
      
    end
    
    %----- Callback for saving the schedule to disk
    function fcnSaveSchedule(schedule, varargin)
      if isempty(schedule.scheduleFile)
        beep;
        errordlg('Invalid state of GUI, scheduleFile is not set. Are you sure you used the TrainingSchedule constructor?', 'Invalid state', 'modal');
        return;
      end
      
      save(schedule.scheduleFile, 'schedule');
      schedule.setSavedState(true);
    end
    
    %----- Callback for running a given program in the scheduled list
    function fcnRunProgram(obj, event, handle, program)
      %% Restart Matlab and run the scheduler at startup, if so desired
      if get(obj.ctrl.restart, 'Value')
        startCmd            = sprintf('matlab -r "cd(''%s''); startup; sc = TrainingSchedule(''%s'',''%s'');" &', TrainingSchedule.START_DIR, obj.scheduleFile, program);
        system(startCmd);
        exit();
      end
      
      %% Run the training program with a refresh request on close
      index                 = find(strcmp(program, obj.schedule), 1, 'first');
      program               = str2func(program);
      obj.completed{index}  = [];

      set(obj.figGUI, 'Pointer', 'watch');
      program([], [], @obj.fcnCheckSchedule);
    end
    
    %----- Callback for running a next program in the scheduled list
    function fcnRunNextProgram(obj, event, handle)
      obj.fcnCheckSchedule();
      
      index                 = find(cellfun(@(x) any(~x), obj.completed), 1, 'first');
      obj.fcnRunProgram(event, handle, obj.schedule{index});
    end
    
    %----- Callback for reordering a given program in the scheduled list
    function fcnReorder(obj, event, handle, program, direction)
      %% Verify that it is possible to reorder in the desired direction
      index                 = find(strcmp(program, obj.schedule), 1, 'first');
      newIndex              = index + direction;
      if newIndex < 1 || newIndex > numel(obj.schedule)
        beep;
        return;
      end
      
      %% Swap all associated objects
      target                = [newIndex, index];
      source                = [index, newIndex];
      obj.schedule(target)  = obj.schedule(source);
      obj.scd(target)       = obj.scd(source);
      obj.scb(target)       = obj.scb(source);
      set(obj.cnt.schedule, 'Contents', obj.scd);

      obj.setSavedState(false);
    end
    
    %----- Callback for removing a given program in the scheduled list
    function fcnRemoveFromSchedule(obj, event, handle, program)
      index                 = find(strcmp(program, obj.schedule), 1, 'first');
      container             = get(get(event, 'Parent'), 'Parent');
      obj.schedule(index)   = [];
      obj.completed(index)  = [];
      obj.scd(obj.scd == container) = [];
      delete(container);
      
      obj.setSavedState(false);
    end
    
    %----- Callback for updating the schedule display according to whether programs have been completed for the day
    function fcnCheckSchedule(obj, event, handle, doForce)
    
      if ~ishghandle(obj.figGUI)
        return;
      end
      if ~exist('doForce', 'var') || isempty(doForce)
        doForce             = false;
      end
      
      %% Update date display, if neccessary
      if ~isequal(obj.refDate, today)
        obj.completed       = cell(size(obj.completed));
        obj.refDate         = today;
        refDate             = datestr(obj.refDate, 'dd mmmm yyyy');
        set(obj.ctrl.day, 'String', refDate, 'FontSize', TrainingSchedule.FONT_SIZE, 'TooltipString', ['Experiments to be run for ' refDate] );
      end      

      %% Indicate busy status
      refDate               = datevec(obj.refDate);
      refDate               = refDate(1:3);
      runNext               = [];
      set(obj.figGUI, 'Pointer', 'watch');
      
      %% Load each regiment and check for the last behavioral entry
      for iProg = 1:numel(obj.schedule)
        %% Run in load-only mode
        if doForce || isempty(obj.completed{iProg})
          descript          = get(obj.scb(iProg), 'String');
          set(obj.scb(iProg), 'String', '... checking ...');
          drawnow;
          
          program           = str2func(obj.schedule{iProg});
          regiment          = program([], 2);
          animal            = regiment.animal([regiment.animal.isActive] == true);
          obj.completed{iProg}  = arrayfun(@(x) ~isempty(x.data) && all(x.data(end).date == refDate), animal);

          whatsDone         = sprintf('&nbsp;&nbsp;&nbsp;(%d/%d)</div>',sum(obj.completed{iProg}),numel(obj.completed{iProg}));
          descript          = regexprep(descript, '(&nbsp;.+)*</div>', whatsDone, 'once');
          set(obj.scb(iProg), 'String', descript);
          drawnow;
        end
        
        %% Indicate status with button highlights
        if isempty(get(obj.scb(iProg), 'UserData'))
          set(obj.scb(iProg), 'UserData', findjobj(obj.scb(iProg)));
        end
        
        jObject             = get(obj.scb(iProg), 'UserData');
        weight              = 'normal';
        background          = get(obj.ctrl.save, 'BackgroundColor');
        if all(obj.completed{iProg})
          color             = TrainingSchedule.CLR_DONE;
          border            = 0;
          background        = TrainingSchedule.BKG_DONE;
        else
          color             = TrainingSchedule.CLR_TODO;
          if isempty(runNext)
            runNext         = iProg;
            border          = TrainingSchedule.BORDER_HILIGHT;
            weight          = 'bold';
            set(obj.ctrl.run, 'TooltipString', ['Run ' obj.schedule{iProg}]);
          else
            border          = 1;
          end
        end
        
        set(obj.scb(iProg), 'FontWeight', weight, 'ForegroundColor', color, 'BackgroundColor', background);
        if border > 0
          jObject.setBorder(javax.swing.border.LineBorder(java.awt.Color(color(1),color(2),color(3)), border, false));
        else
          jObject.setBorder(javax.swing.border.EmptyBorder(1,1,1,1));
        end
        jObject.repaint();
        
      end
      
      %% Restore status
      set(obj.figGUI, 'Pointer', 'arrow');
    end
    
    %----- Callback for adding a new program to the scheduled list
    function fcnAddToSchedule(obj, event, handle)
      %% Query user for program
      if ischar(event)
        program             = event;
      else
        program             = uigetfile(TrainingSchedule.PROGRAM_MASK, 'Select training program');
        if program == 0
          return;
        end
        [~,program]         = parsePath(program);
      end
      
      %% Verify output format
      if nargout(program) ~= 1 || (nargin(program) >= 0 && nargin(program) < 2)
        beep;
        errordlg(sprintf('Program "%s" is not valid, it should have 1 output argument (regiment) and >= 2 input arguments.', program), 'Invalid program', 'modal');
        return;
      end
      
      if ~ischar(event) && any(strcmp(program, obj.schedule))
        beep;
        errordlg(sprintf('Program "%s" is already scheduled. Remove it first if you want to reorder.', program), 'Duplicate program', 'modal');
        return;
      end
      
      %% Format name
      name                  = strrep(program, '_', ' ');
      if numel(name) > TrainingSchedule.MAX_LINE_LENGTH
        iSpace              = find(name == ' ');
        if isempty(iSpace)
          iBreak            = ceil(numel(name)/2);
        else
          [~,iBreak]        = min(abs(iSpace - numel(name)/2));
          iBreak            = iSpace(iBreak);
        end
        name                = [name(1:iBreak-1) '<br/>' name(iBreak:end)];
      end
      name                  = sprintf('<html><div width="%dpx" align="left">%s</div></html>', 0.75*TrainingSchedule.BUTTON_WIDTH - TrainingSchedule.BUTTON_HEIGHT, name);
      
      %% Add to end of list
      obj.scd(end+1)        = obj.scd(end);               % Displace add button
      obj.scd(end-1)        = uix.HBox('Parent', obj.cnt.schedule, 'Spacing', 5);
      obj.scb(end+1)        = uicontrol( 'Parent', obj.scd(end-1), 'Style', 'pushbutton', 'String', name, 'TooltipString', program    ...
                                       , 'FontSize', TrainingSchedule.FONT_SIZE-2, 'Callback', {@obj.fcnRunProgram, program} );
      cntOrder              = uix.VBox('Parent', obj.scd(end-1), 'Spacing', 1);
      uicontrol( 'Parent', cntOrder, 'Style', 'pushbutton', 'String', '<html>&uarr;</html>', 'FontSize', TrainingSchedule.FONT_SIZE, 'Callback', {@obj.fcnReorder, program, -1} );
      uicontrol( 'Parent', cntOrder, 'Style', 'pushbutton', 'String', '<html>&darr;</html>', 'FontSize', TrainingSchedule.FONT_SIZE, 'Callback', {@obj.fcnReorder, program, +1} );
      uicontrol( 'Parent', cntOrder, 'Style', 'pushbutton', 'String', '-', 'FontSize', TrainingSchedule.FONT_SIZE+3, 'Callback', {@obj.fcnRemoveFromSchedule, program} );

      set(obj.scd(end-1), 'Widths', [-1, 0.6*TrainingSchedule.BUTTON_HEIGHT]);
      set(obj.cnt.schedule, 'Contents', obj.scd);
      
      if ~ischar(event)
        obj.schedule{end+1} = program;
        obj.completed{end+1}= [];
        obj.setSavedState(false);
      end
    end
    
  end
  
  %________________________________________________________________________
  methods (Access = protected)

    %----- Set GUI display depending on whether there are unsaved changes to the schedule
    function setSavedState(obj, isSaved)
      if ~exist('isSaved', 'var') || isempty(isSaved)
        isSaved       = obj.savedOnDisk;
      end
      obj.savedOnDisk = isSaved;

      if ishghandle(obj.figGUI)
        if obj.savedOnDisk
          set(obj.ctrl.save, 'BackgroundColor', TrainingSchedule.CLR_SAVED, 'String', 'Saved', 'FontWeight', 'normal');
        else
          set(obj.ctrl.save, 'BackgroundColor', TrainingSchedule.CLR_DIRTY, 'String', 'SAVE', 'FontWeight', 'bold');
        end
      end
    end
    
  end
  
  %________________________________________________________________________
  methods (Static)

    %----- Structure conversion to load an object of this class from disk
    function obj = loadobj(frozen)
      obj               = TrainingSchedule('');
      for field = fieldnames(frozen)'
        obj.(field{:})  = frozen.(field{:});
      end
    end
    
  end
  
end
