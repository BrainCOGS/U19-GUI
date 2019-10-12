classdef AnimalOverview < handle
  
  %_________________________________________________________________________________________________
  properties (Constant)
    MAGIC_VARIABLE    = '$$'
    RGX_PLOTFCN       = '^\s*Static\s+handle\s+(plot)([^\(]+)'

    GUI_MONITOR       = getMonitorBySize(true)
    HEADER_WIDTH      = 200
    HEADER_HEIGHT     = 50
    DEFAULT_PLOTSIZE  = 250
    MARGIN_PLOTWIDTH  = 60
    MARGIN_PLOTHEIGHT = 40
    
    CLR_NOTUSED       = [1 1 1]*0.5;
    CLR_MODIFIED      = [255 233 204]/255;
    
    PRESET_SAVEFILE   = fullfile(fileparts(mfilename('fullpath')), 'aniOverview_presets.mat')
    PRESET_CATEGORIES = { 'ID / Maze'       , {'animal.ID',DisplayAs.Row; 'log.mazeID',DisplayAs.Color}  ...
                        ; 'Maze / Rig / ID' , {'log.mazeID',DisplayAs.Row; 'log.rigName',DisplayAs.Col; 'animal.ID',DisplayAs.Color}  ...
                        };
  end
  
  %_________________________________________________________________________________________________
  properties (Access = protected, Transient)
    figGUI      = gobjects(0)
    
    cnt         = struct()
    pnl         = struct()
    btn         = struct()
    edt         = struct()
    lst         = struct()
    tbl         = struct()
    axs         = struct()
    plt         = struct()
  end
  
  %_________________________________________________________________________________________________
  properties (SetAccess = protected)
    dbase
    tmplAnimal
    tmplLog
    animal
    log
    magic
  end  
  
  %_________________________________________________________________________________________________
  %
  %   Define data plotting functions here
  %
  %   All functions must have the form:
  %       handle = plotXXX(axs, logs)
  %   where XXX (but nothing else!) can be replaced by you. The function should take:
  %       axs       : an axes object to plot in
  %       data      : data (in the form of daily logs) to use to create a single plot
  %       color     : preferred line color for the plot
  %       template  : (optional to use) information about various fields in the data struct; will be
  %                   empty for all but the first plot in the displayed set
  %   and must return a representative handle to the created graphical object, to be used in
  %   legends.
  %
  methods (Static)

    function handle = plotPerformance(axs, data, color, template)
      
      %% Format axis labels
      ylabel(axs, '% correct');
      axis(axs, 'tight');
      set(axs, 'YLim', [0 100]);
      
      if isempty(data.date)
        handle            = gobjects(1);
        return;
      end
      
      %% Compute performance per day
      [dates,~,index]     = unique(data.date);
      dates               = accumfun(1, @AnimalDatabase.num2date, dates);
      dates               = datetime(dates);
      isCorrect           = data.choice == data.trialType;
      numCorrect          = nan(size(dates));
      numTrials           = nan(size(dates));
      for iDate = 1:numel(dates)
        trialCorrect      = isCorrect(index == iDate);
        numCorrect(iDate) = sum(trialCorrect);
        numTrials(iDate)  = numel(trialCorrect);
      end
      
      %% Compute binomial uncertainty for the fraction of correct trials
      [performance,pci]   = binointerval(numCorrect, numTrials, normcdf(-1));
      pci                 = pci';
      pci(end+1,:)        = nan;
      
      %% Draw a line with markers if there are few enough points
      markers             = {};
      if numel(performance) < 32
        markers           = {'Marker', '.', 'MarkerSize', 15};
      end
      handle              = plot( axs, dates, 100*performance                   ...
                                , 'LineWidth'         , 1                       ...
                                , 'Color'             , color                   ...
                                , markers{:}                                    ...
                                );
      dates               = repmat(dates(:)', 3, 1);
                   uistack( plot( axs, dates(:), 100*pci(:)                     ...
                                , 'LineWidth'         , 1                       ...
                                , 'Color'             , 0.3*color + 0.7*[1 1 1] ...
                                ), 'bottom' );
                              
    end
    
    function handle = plotPsychometric(axs, data, color, template)

      deltaBins           = -15:3:15;       % controls binning of #R - #L
      deltaBins           = deltaBins(:);
      
      %% Format axis labels
      xRange              = deltaBins([1 end]) + [-2; 2];
      ylabel(axs, '% went R');
      xlabel(axs, '#R - #L');
      set(axs, 'XLim', xRange, 'YLim', [0 100]);
      
      if isempty(data.date)
        handle            = gobjects(1);
        return;
      end
      
      %% Compute trials where the animal went right vs. evidence strength
      numRight            = zeros(numel(deltaBins),1);
      numTrials           = zeros(numel(deltaBins),1);
      trialDelta          = zeros(numel(deltaBins),1);
      nCues_RminusL       = data.numTowersR - data.numTowersL;
      trialBin            = binarySearch(deltaBins, nCues_RminusL, 0, 2);
      for iTrial = 1:numel(data.choice)
        numTrials(trialBin(iTrial))   = numTrials(trialBin(iTrial)) + 1;
        if data.choice(iTrial) == Choice.R
          numRight(trialBin(iTrial))  = numRight(trialBin(iTrial)) + 1;
        end
        trialDelta(trialBin(iTrial))  = trialDelta(trialBin(iTrial)) + nCues_RminusL(iTrial);
      end
      trialDelta          = trialDelta ./ numTrials;

      
      %% Logistic function fit
      [phat,pci]          = binointerval(numRight, numTrials, normcdf(-1));
      sigmoid             = @(O,A,lambda,x0,x) O + A ./ (1 + exp(-(x-x0)/lambda));
      sel                 = numTrials > 0;
      if sum(sel) < 5
        psychometric      = [];
      else
        psychometric      = fit ( deltaBins(sel), phat(sel), sigmoid                      ...
                                , 'StartPoint'      , [0 1 8 0]                           ...
                                , 'Weights'         , ((pci(sel,2) - pci(sel,1))/2).^-2   ...
                                , 'MaxIter'         , 400                                 ...
                                ); 
      end
      pci(:,end+1)        = nan;
      delta               = linspace(deltaBins(1)-2, deltaBins(end)+2, 50);

      %% Draw a line with error bars for data
      errorX              = repmat(trialDelta(sel)', 3, 1);
      errorY              = pci(sel,:)';
                            line( 'Parent'            , axs                     ...
                                , 'XData'             , errorX(:)               ...
                                , 'YData'             , 100*errorY(:)           ...
                                , 'LineWidth'         , 1                       ...
                                , 'Color'             , color                   ...
                                );
      handle              = line( 'Parent'            , axs                     ...
                                , 'XData'             , trialDelta(sel)         ...
                                , 'YData'             , 100*phat(sel)           ...
                                , 'LineStyle'         , 'none'                  ...
                                , 'Color'             , color                   ...
                                , 'Marker'            , '.'                     ...
                                , 'MarkerSize'        , 15                      ...
                                );
      if ~isempty(psychometric)
        handle            = line( 'Parent'            , axs                     ...
                                , 'XData'             , delta                   ...
                                , 'YData'             , 100*psychometric(delta) ...
                                , 'LineWidth'         , 1                       ...
                                , 'Color'             , color                   ...
                                );
      end
                              
    end
    
    function handle = plotDailyTrend(axs, data, color, template)
      
      handle              = gobjects(1);
      
      %% Prompt the user to select a variable to plot
      persistent what;
      if ~isempty(template)
        daily             = template(~[template.isTrials] & [template.isNumeric] & ~strcmp({template.identifier},'date'));
        [~,index]         = listInputDialog ( 'Variable to plot', 'Select a variable to plot across days:'      ...
                                            , {daily.identifier}, {false,{daily.description}}, false, true      ...
                                            , AnimalDatabase.GUI_FONT, [], AnimalOverview.GUI_MONITOR           ...
                                            );
        what              = daily(index);
      end
      
      if isempty(what)
        return;
      end
      
      %% Format axis labels
      ylabel(axs, what.field);
      axis(axs, 'tight');
      axis(axs, 'auto y');
      
      if isempty(data.date)
        handle            = gobjects(1);
        return;
      end
      
      %% Get quantity by day, showing the min/max extent of values
      [dates,~,index]     = unique(data.date);
      dates               = accumfun(1, @AnimalDatabase.num2date, dates);
      dates               = datetime(dates);
      values              = nan(size(dates));
      range               = nan(3,numel(values));
      for iDate = 1:numel(dates)
        daily             = data.(what.identifier)(index == iDate);
        values(iDate)     = mean(daily);
        range(1,iDate)    = max(daily);
        range(2,iDate)    = min(daily);
      end
      
      %% Draw a line with markers if there are few enough points
      markers             = {};
      if numel(values) < 32
        markers           = {'Marker', '.', 'MarkerSize', 15};
      end
      handle              = plot( axs, dates, values                            ...
                                , 'LineWidth'         , 1                       ...
                                , 'Color'             , color                   ...
                                , markers{:}                                    ...
                                );
      dates               = repmat(dates(:)', 3, 1);
                   uistack( plot( axs, dates(:), range(:)                       ...
                                , 'LineWidth'         , 1                       ...
                                , 'Color'             , 0.3*color + 0.7*[1 1 1] ...
                                ), 'bottom' );
                              
    end
    
  end
    
  %_________________________________________________________________________________________________
  methods (Static)

    %----- Gets the list of all defined plotting functions for this class
    function [name, fcn] = getPlottingFunctions()
      metadata          = methods('AnimalOverview', '-full');
      match             = regexp(metadata, AnimalOverview.RGX_PLOTFCN, 'tokens', 'once');
      match( cellfun(@isempty,match) )  = [];
      name              = cellfun(@(x) x{2}, match, 'UniformOutput', false);
      fcn               = cellfun(@(x) str2func(['AnimalOverview.' x{1} x{2}]), match, 'UniformOutput', false);
    end
    
    %----- Generates an empty output struct that has either numeric or cell arrays depending on a template
    function [data, template] = emptyForTemplate(template)
      %% Additional tests for numeric/trial/filter data
      isNumeric             = num2cell( arrayfun(@(x) ~isempty(regexp(x.data{2},[AnimalDatabase.RGX_PRECISION '[dgf]'],'once')), template)  ...
                                      | arrayfun(@(x) ~isempty(strfind(x.data{2},'DATE')), template)                                        ...
                                      );
      if isfield(template, 'isTrials')
        isTrials            = num2cell( strcmpi({template.isTrials}, 'yes') );
      else
        isTrials            = num2cell( false(size(template)) );
      end
      isFilter              = num2cell( strcmpi({template.isFilter}, 'yes') );
      [template.isNumeric]  = isNumeric{:};
      [template.isTrials]   = isTrials{:};
      [template.isFilter]   = isFilter{:};
      
      %% Select only the subset of either filter candidates or trial-based data
      template( ~[template.isTrials] & ~[template.isFilter] )  = [];
      
      %% Generate an empty struct with the appropriate field type
      isNumeric             = [template.isNumeric];
      data                  = {template.identifier};
      [data{2, isNumeric}]  = deal({[]});
      [data{2,~isNumeric}]  = deal({{}});
      data                  = struct(data{:});
    end
    
    
    %----- Toggle the type of categorization that the given control is used for
    function toggleCategorizations(hObject, event, direction, forceValue)
      if nargin < 4
        forceValue    = [];
      end
      
      %% Start from either the stored state, or the next global state
      info            = get(hObject, 'UserData');
      state           = get(info{3}, 'UserData');
      if ~isempty(forceValue)
        value         = forceValue;
      elseif isempty(info{2})
        value         = DisplayAs.cycle(state{5}, direction);
        if value == DisplayAs.None
          value       = DisplayAs.cycle(value, direction);
        end
      else
        value         = DisplayAs.cycle(info{2}, direction);
      end
      
      if isempty(forceValue)
        state{5}      = value;
        set(info{3}, 'UserData', state);
      end
      
      %% Display indicators for the currently set state
      info{2}         = value;
      set(hObject, 'ForegroundColor', DisplayAs.color(value), 'UserData', info);
      if value == DisplayAs.None
        set(hObject, 'String', info{1}, 'Value', 0, 'FontWeight', 'normal');
      else
        set(hObject, 'String', ['[' lower(char(value)) '] ' info{1}], 'Value', 1, 'FontWeight', 'bold');
      end
    end
    
    %----- Sets the selected state to off for all provided handles, or restores a previously saved setting
    function clearOrRestore(hObject, event, doClear, handles, colorFcn)
      state             = get(hObject, 'UserData');
      
      if doClear
        %% Clear all values but first store the state
        state{3}        = arrayfun(@(x) get(x,'Value')==1, handles);
        set(hObject, 'UserData', state);
        
        for iObj = 1:numel(handles)
          info          = get(handles(iObj), 'UserData');
          set(handles(iObj), 'String', info{1}, 'Value', 0, 'FontWeight', 'normal', 'ForegroundColor', AnimalOverview.CLR_NOTUSED);
        end
        
      else
        %% Restore saved values (albeit not settings) and display indicators
        for iObj = 1:numel(handles)
          info          = get(handles(iObj), 'UserData');
          value         = info{2};
          
          if state{3}(iObj)
            set(handles(iObj), 'String', ['[' lower(char(value)) '] ' info{1}], 'Value', 1, 'FontWeight', 'bold', 'ForegroundColor', colorFcn(value));
          else
            set(handles(iObj), 'String', info{1}, 'Value', 0, 'FontWeight', 'normal', 'ForegroundColor', AnimalOverview.CLR_NOTUSED);
          end
        end
      end
    end
    
    
    %----- Gets a numeric value from a uicontrol, defaulting to some given value if invalid
    function value = getEnteredNumber(handle, defaultValue)
      value         = str2double( get(handle,'String') );
      if isnan(value)
        value       = defaultValue;
        set(handle, 'String', num2str(value));
      end
    end
    
    %----- Changes the background color of a uicontrol to indicate that the user has manually edited it
    function flagUserEdit(jObject, event, hObject)
      filterExpr  = get(hObject, 'UserData');
      expression  = char(jObject.getText);
      if strcmp( regexprep(expression,'\s',''), regexprep(filterExpr,'\s','') )
        color     = [1 1 1];
        tip       = 'Expression corresponding to selected filters';
      else
        color     = AnimalOverview.CLR_MODIFIED;
        tip       = 'User-entered expression; overrides filters';
      end
      set(hObject, 'BackgroundColor', color, 'TooltipString', ['<html><div style="font-size:14px">' tip '</div></html>']);
    end
    
  end
  
  %_________________________________________________________________________________________________
  methods (Access = protected)
    
    %----- Generate a per-trial flat structure of data by replicating block-level quantities
    function [animal, log, tmplAnimal, tmplLog] = flattenData(obj, animals, logs, tmplAnimal, tmplLog)
      %% Additional templates for computed quantities
      tmplAnimal(end+1).identifier  = 'owner';      % HACK
      tmplAnimal(end).description   = 'ID of researcher that owns this mouse';
      tmplAnimal(end).data          = AnimalDatabase.SPECS_TEXT;
      tmplAnimal(end).isFilter      = 'yes';
      
      tmplLog(end+1).field            = 'Number of trials';
      tmplLog(end).description        = 'Number of trials in session';
      tmplLog(end).identifier         = 'numTrials';
      tmplLog(end).data               = {':', '%d', ''};
      tmplLog(end).isFilter           = 'yes';
      
      tmplLog(end+1).field            = 'Session duration';
      tmplLog(end).description        = 'Duration of training session in minutes';
      tmplLog(end).identifier         = 'durationMins';
      tmplLog(end).data               = {':', '%.3g', ''};
      tmplLog(end).isFilter           = 'yes';

      %% Data storage and prerequisite info
      [animal,tmplAnimal]           = AnimalOverview.emptyForTemplate(tmplAnimal);
      [log,tmplLog]                 = AnimalOverview.emptyForTemplate(tmplLog);
      trialData                     = {tmplLog.identifier};
      trialData(~[tmplLog.isTrials])= [];
      
      %% Loop over animals and their logs
      isFirst             = true;
      for iAni = 1:numel(animals)
        for iLog = 1:numel(logs{iAni})
          %% Consider only days with nonzero number of trials
          daily           = logs{iAni}(iLog);
          [numTrials,~,iSet]  = unique(cellfun(@(x) numel(daily.(x)), trialData));
          if numel(numTrials) ~= 1
            counts        = arrayfun(@(x) sprintf('%d -> %s', numTrials(x), strjoin(trialData(iSet==x),', ')), 1:numel(numTrials), 'UniformOutput', false);
            warning( 'AnimalOverview:flattenData', 'Invalid %s daily log for %s (researcher %s), has inconsistent number of entries for trial-data variables:\n    %s\nThis data will be omitted from analysis.'  ...
                   , obj.dbase.applyFormat(daily.date, AnimalDatabase.SPECS_DATE), animals(iAni).ID, animals(iAni).owner, strjoin(counts, [char(10),'    ']) );
             continue;
          end
          if numTrials < 1
            %% Fill fake data so that animal information can be plotted across days with no behavioral recordings
            for field = trialData
              daily.(field{:})  = nan;
            end
            numTrials     = 1;
          end
          
          %% Additional computed info for convenience
          daily.numTrials       = numTrials;
          if isempty(daily.trainEnd)
            daily.durationMins  = nan;
          else
            daily.durationMins  = ( AnimalDatabase.time2days(daily.trainEnd) - AnimalDatabase.time2days(daily.trainStart) ) * 24*60;
          end
          
          %% Trial-indexed data range
          range           = 1:numTrials;
          if isFirst
            isFirst       = false;
          else
            range         = range + numel(log.(trialData{1}));
          end
          
          %% Handle different types of data for concatenation or replication
          for iTmpl = 1:numel(tmplLog)
            field         = tmplLog(iTmpl).identifier;
            [str,number]  = obj.dbase.applyFormat(daily.(field), tmplLog(iTmpl).data, true);
            
            if ~tmplLog(iTmpl).isTrials && ~tmplLog(iTmpl).isNumeric    % Replicate all day-based quantities
              [log.(field){range}]        = deal(str);
            elseif isempty(daily.(field))              % Numeric data is assumed to be nan if not available
              log.(field)(range)          = nan;
            else
              if length(number)>1
                  number = number(end);
              end
              log.(field)(range)          = number;
            end
          end
        end
        
        %% Replicate animal-level info
        range             = numel(animal.(tmplAnimal(1).identifier)) + 1:numel(log.(trialData{1}));
        if isempty(range)
          continue;
        end
        
        info              = animals(iAni);
        for iTmpl = 1:numel(tmplAnimal)
          field           = tmplAnimal(iTmpl).identifier;
          [str,number]    = obj.dbase.applyFormat(info.(field), tmplAnimal(iTmpl).data, true);
            
          if ~tmplAnimal(iTmpl).isNumeric               % Replicate all per-animal quantities
            [animal.(field){range}]       = deal(str);
          elseif isempty(info.(field))                  % Numeric data is assumed to be nan if not available
            animal.(field)(range)         = nan;
          else
            animal.(field)(range)         = number;
          end
        end
      end
      
      %% Hack to treat dates as numbers for ease of comparisons etc.
      [tmplAnimal( arrayfun(@(x) ~isempty(strfind(x.data{2},'DATE')), tmplAnimal) ).data]   ...
                          = deal(AnimalDatabase.SPECS_INTEGER);
      [tmplLog( arrayfun(@(x) ~isempty(strfind(x.data{2},'DATE')), tmplLog) ).data]         ...
                          = deal(AnimalDatabase.SPECS_INTEGER);
    end
    
    
    %----- (Re-)create GUI figure and layout for animal info display
    function layoutGUI(obj)

      %% Create figure to populate
      obj.closeGUI();
      obj.figGUI              = makePositionedFigure( AnimalDatabase.GUI_POSITION                     ...
                                                    , AnimalOverview.GUI_MONITOR                      ...
                                                    , 'OuterPosition'                                 ...
                                                    , 'Name'            , [AnimalDatabase.GUI_TITLE ' Overview']  ...
                                                    , 'ToolBar'         , 'none'                      ...
                                                    , 'MenuBar'         , 'none'                      ...
                                                    , 'NumberTitle'     , 'off'                       ...
                                                    , 'Visible'         , 'off'                       ...
                                                    , 'CloseRequestFcn' , @obj.closeGUI               ...
                                                    );
      
      %% Define main controls and data display regions
      obj.cnt.main            = uix.HBoxFlex( 'Parent', obj.figGUI, 'Spacing', 3*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.dataSel         = uix.VBox( 'Parent', obj.cnt.main, 'Spacing', 4*AnimalDatabase.GUI_BORDER, 'Padding', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.dataDisp        = uix.VBoxFlex( 'Parent', obj.cnt.main, 'Spacing', 3*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      %% Left panel: data filters
      [plotName, plotFcn]     = AnimalOverview.getPlottingFunctions();
      infoFilter              = obj.tmplAnimal( [obj.tmplAnimal.isFilter] );
      dailyFilter             = obj.tmplLog( [obj.tmplLog.isFilter] );
      allFilters              = [strcat({'animal.'}, {infoFilter.identifier}), strcat({'log.'}, {dailyFilter.identifier})];
      templates               = [num2cell(infoFilter), num2cell(dailyFilter)];
      category                = {'Filter', 'Categorization'};
      description             = {'Apply these filters to select data to plot', 'Split plots according to these categories'};
      toggling                = {'cycle', 'restore'};

      % Type of plots to make
      obj.lst.plotType        = uicontrol( 'Parent', obj.cnt.dataSel, 'Style', 'popupmenu', 'String', plotName, 'UserData', plotFcn                                 ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Type of plot to show</div></html>'                                   ...
                                         , 'FontSize', AnimalDatabase.GUI_FONT, 'Callback', @obj.generatePlots, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      filterHeights           = AnimalDatabase.GUI_BTNSIZE;
      
      % Types of filters/categorizers to apply
      for iCat = 1:numel(category)
        %% Overall control of filter mode/clear selections
        name                  = strrep(category{iCat}, ' ', '');
        name(1)               = lower(name(1));
        
        cntCategory           = uix.VBox( 'Parent', obj.cnt.dataSel, 'Spacing', 1, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        obj.btn.(name)        = uicontrol( 'Parent', cntCategory, 'Style', 'pushbutton', 'String', category{iCat}, 'FontSize', AnimalDatabase.GUI_FONT          ...
                                         , 'TooltipString', ['<html><div style="font-size:14px">' description{iCat} '<br/>Right-click to clear ; Left-click to ' toggling{iCat} '</div></html>'] ...
                                         , 'FontWeight', 'bold', 'Interruptible', 'off', 'BusyAction', 'cancel' );
        
        %% Individual filter selections
        cntScroll             = uix.ScrollingPanel( 'Parent', cntCategory );
        cntFilter             = uix.VButtonBox( 'Parent', cntScroll, 'Spacing', 1, 'ButtonSize', [6 0.9]*AnimalDatabase.GUI_BTNSIZE, 'VerticalAlignment', 'top', 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        filterHeights(end+1)  = -1;
        obj.lst.(name)        = gobjects(size(allFilters));
        for iFilter = 1:numel(allFilters)
          obj.lst.(name)(iFilter)                                                                                                                               ...
                              = uicontrol( 'Parent', cntFilter, 'Style', 'togglebutton', 'String', allFilters{iFilter}, 'FontSize', AnimalDatabase.GUI_FONT     ...
                                         , 'TooltipString', ['<html><div style="font-size:14px">' templates{iFilter}.description '</div></html>']               ...
                                         , 'ForegroundColor', AnimalOverview.CLR_NOTUSED, 'Interruptible', 'off', 'BusyAction', 'cancel' );
          if iCat == 1
            set( obj.lst.(name)(iFilter), 'Callback', @obj.selectFilterValues, 'ButtonDownFcn', @obj.clearFilterValues                                          ...
               , 'UserData', {name, allFilters{iFilter}, templates{iFilter}, {}} );
          else
            set( obj.lst.(name)(iFilter), 'Callback', {@AnimalOverview.toggleCategorizations,1}, 'ButtonDownFcn', {@AnimalOverview.toggleCategorizations,-1}    ...
               , 'UserData', {allFilters{iFilter}, [], obj.btn.(name), templates{iFilter}} );
          end
        end
        
        set(cntCategory, 'Heights', [AnimalDatabase.GUI_BTNSIZE,-1]);
        set(cntScroll, 'MinimumHeights', numel(allFilters) * 0.9 * AnimalDatabase.GUI_BTNSIZE + (numel(allFilters)+1));
        
        %% Distinguish filters vs. categorization controls
        if iCat == 1
          set( obj.btn.(name), 'Callback', {@obj.toggleFilterState,-1}, 'ButtonDownFcn', {@obj.toggleFilterState,1} );
        else
          set( obj.btn.(name), 'Callback', {@AnimalOverview.clearOrRestore,false,obj.lst.(name),@DisplayAs.color}   ...
                             , 'ButtonDownFcn', {@AnimalOverview.clearOrRestore,true,obj.lst.(name),@DisplayAs.color} );
        end
        set( obj.btn.(name), 'UserData', {name, FilterState.Off, arrayfun(@(x) get(x,'Value')==1,obj.lst.(name)), category{iCat}, DisplayAs.None} );
      end
                                       
      
      %% Right panel: filter expressions and plots
      obj.cnt.config          = uix.HBox( 'Parent', obj.cnt.dataDisp, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.plotScroll      = uix.ScrollingPanel( 'Parent', obj.cnt.dataDisp, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.plots           = uix.Grid( 'Parent', obj.cnt.plotScroll, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );

      obj.cnt.expressions     = uix.VBox( 'Parent', obj.cnt.config, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.controls        = uix.VButtonBox( 'Parent', obj.cnt.config, 'Spacing', AnimalDatabase.GUI_BORDER, 'Padding', 3*AnimalDatabase.GUI_BORDER    ...
                                              , 'ButtonSize', [3 1]*AnimalDatabase.GUI_BTNSIZE, 'HorizontalAlignment', 'right', 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      %% Filter expression and support for arbitrary user-entered formulae
      for iCat = 1
        name                  = strrep(category{iCat}, ' ', '');
        name(1)               = lower(name(1));
        obj.edt.(name)        = uicontrol( 'Parent', obj.cnt.expressions, 'Style', 'edit', 'Min', 0, 'Max', 1, 'HorizontalAlignment', 'left'                        ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Expression corresponding to selected filters</div></html>'           ...
                                         , 'UserData', '', 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel' );
        jEditBox              = findjobj(obj.edt.(name));
        set(jEditBox, 'KeyPressedCallback', {@AnimalOverview.flagUserEdit, obj.edt.(name)});
      end
      
      %% Presets and magic variables
      obj.cnt.format          = uix.HBox( 'Parent', obj.cnt.expressions, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );

      obj.lst.presetCat       = uicontrol( 'Parent', obj.cnt.format, 'Style', 'popupmenu'                                                                                                 ...
                                         , 'String', [{'<html><div style="color:gray; font-style:italic">--- Preset Categories ---</div></html>'}; AnimalOverview.PRESET_CATEGORIES(:,1)] ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Apply a preset category setting -- N.B. this will clear current selections!</div></html>'  ...
                                         , 'Callback', @obj.applyPresetCategories, 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel' );

      magicExpr               = {};
      for field = fieldnames(obj.magic)'
        if ~isnumeric(obj.magic.(field{:}))
          value               = obj.magic.(field{:});
        elseif all( floor(obj.magic.(field{:})) == obj.magic.(field{:}) )
          value               = int2str( obj.magic.(field{:}) );
        else
          value               = num2str( obj.magic.(field{:}), '%.4g' );
        end
        magicExpr{end+1}      = ['<html>magic.' field{:} '<font color="blue"> = ' value '</font></html>'];
      end
      obj.lst.magic           = uicontrol( 'Parent', obj.cnt.format, 'Style', 'popupmenu', 'UserData', strcat({'magic.'}, fieldnames(obj.magic))                                          ...
                                         , 'String', [{'<html><div style="color:gray; font-style:italic">--- Predefined variables ---</div></html>'}; magicExpr]                          ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Variables that can be used in filter expressions<br/>Select to copy name to clipboard</div></html>'  ...
                                         , 'Callback', @obj.copyMagicVariable, 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      
      
      %% Plot formatting
      label                   = {'Aspect Ratio', 'Plot Size'};
      default                 = {'1', num2str(AnimalOverview.DEFAULT_PLOTSIZE)};
      description             = {'Aspect ratio (x/y extent) of plots', 'Minimum width/height of plots, in pixels'};
      style                   = {'edit', 'edit'};
      for iSet = 1:numel(label)
        name                  = strrep(label{iSet}, ' ', '');
        name(1)               = lower(name(1));
                                uicontrol( 'Parent', obj.cnt.format, 'Style', 'text', 'String', [label{iSet} ' : '], 'HorizontalAlignment', 'right'                 ...
                                         , 'TooltipString', ['<html><div style="font-size:14px">' description{iSet} '</div></html>']                                ...
                                         , 'FontSize', AnimalDatabase.GUI_FONT, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        obj.edt.(name)        = uicontrol( 'Parent', obj.cnt.format, 'Style', style{iSet}, 'String', default{iSet}, 'HorizontalAlignment', 'left'                   ...
                                         , 'TooltipString', ['<html><div style="font-size:14px">' description{iSet} '</div></html>']                                ...
                                         , 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel' );
        if strcmp(style{iSet}, 'checkbox')
          set(obj.edt.(name), 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG);
        end
      end
      
      % Refresh plots with the current settings
      uix.Empty('Parent', obj.cnt.format);
      obj.btn.doPlot          = uicontrol( 'Parent', obj.cnt.format, 'Style', 'pushbutton', 'String', 'Generate Plots', 'FontWeight', 'bold'                        ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Create plots using the current settings</div></html>'                ...
                                         , 'Callback', @obj.generatePlots, 'FontSize', AnimalDatabase.GUI_FONT+1, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      
      %% Settings save/load
      obj.btn.save            = uicontrol( 'Parent', obj.cnt.controls, 'Style', 'pushbutton', 'String', 'Save', 'FontSize', AnimalDatabase.GUI_FONT                 ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Save data filters</div></html>'                                      ...
                                         , 'Callback', @obj.saveConfiguration, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      obj.btn.load            = uicontrol( 'Parent', obj.cnt.controls, 'Style', 'pushbutton', 'String', 'Load', 'FontSize', AnimalDatabase.GUI_FONT                 ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Load data filters</div></html>'                                      ...
                                         , 'Callback', @obj.loadConfiguration, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      
      
      %% Configure layout proportions
      set(obj.cnt.main       , 'Widths' , [7*AnimalDatabase.GUI_BTNSIZE, -1]);
      set(obj.cnt.dataSel    , 'Heights', filterHeights);
      set(obj.cnt.expressions, 'Heights', [-1, AnimalDatabase.GUI_BTNSIZE]);
      set(obj.cnt.dataDisp   , 'Heights', [2.5*AnimalDatabase.GUI_BTNSIZE, -1]);
      set(obj.cnt.format     , 'Widths' , [[7 9]*AnimalDatabase.GUI_BTNSIZE, AnimalDatabase.GUI_BTNSIZE * repmat([5 3],1,numel(label)), -1, 5*AnimalDatabase.GUI_BTNSIZE]);
      set(obj.cnt.config     , 'Widths' , [-1, 3.5*AnimalDatabase.GUI_BTNSIZE]);

      executeCallback(obj.btn.filter);
      set(obj.figGUI, 'Visible', 'on');

    end
    
    
    %----- Toggle filters between AND and OR logic
    function toggleFilterState(obj, hObject, event, direction, forceValue)
      if nargin < 5
        forceValue    = [];
      end
      
      %% Cycle through available states
      info            = get(hObject, 'UserData');
      value           = FilterState.cycle(info{2}, direction);
      if ~isempty(forceValue)
        value         = forceValue;
      elseif info{2} == FilterState.Off         % was off, restore previous selection
        set(obj.lst.(info{1})(info{3}), 'Value', 1, 'ForegroundColor', AnimalDatabase.CLR_SELECT);
      elseif value == FilterState.Off       % now off, store current selection and turn off filters
        info{3}       = arrayfun(@(x) get(x,'Value')==1, obj.lst.(info{1}));
        set(obj.lst.(info{1}), 'Value', 0, 'ForegroundColor', AnimalOverview.CLR_NOTUSED);
      end

      %% Set indicators of current state
      info{2}         = value;
      set(hObject, 'String', ['<html>' info{4} ' : ' FilterState.html(value) '</html>'], 'BackgroundColor', FilterState.background(value), 'UserData', info);
      obj.updateFilterExpression(hObject);
    end
    
    %----- Construct a filter selection 
    function selectFilterValues(obj, hObject, event)
      %% Get list of possible values
      info        = get(hObject, 'UserData');
      animal      = obj.animal;
      log         = obj.log;
      template    = info{3};
      data        = eval(info{2});
      if template.isNumeric
        values    = unique(data(~arrayfun(@isnan, data)));
        values    = arrayfun(@(x) obj.dbase.applyFormat(x,template.data,true), values, 'UniformOutput', false);
      else
        values    = unique(data);
        values    = cellfun(@(x) strrep(x,char(10),'/'), values, 'UniformOutput', false);
        values(cellfun(@isempty,values))  = [];
      end
      
      %% Prompt user to select from the list
      selection   = listInputDialog ( ['Add ' info{1}], { sprintf('ismember({%s}, <SELECT FROM LIST>)', info{2})                                    ...
                                                        , ['or enter a custom expression with placeholder "' AnimalOverview.MAGIC_VARIABLE '":']   ...
                                                        }                                                                                           ...
                                    , values, [], info{4}, true, AnimalDatabase.GUI_FONT, [], AnimalOverview.GUI_MONITOR );
                                  
      if isempty(selection)
        set(hObject, 'Value', 0, 'ForegroundColor', AnimalOverview.CLR_NOTUSED);
      else
        info{4}   = selection;
        set(hObject, 'UserData', info, 'Value', 1, 'ForegroundColor', AnimalDatabase.CLR_SELECT);
        
        %% Must have a valid combination logic
        state     = get(obj.btn.filter, 'UserData');
        if state{2} == FilterState.Off
          obj.toggleFilterState(obj.btn.filter, [], -1, FilterState.AND);
        end
      end
      
      %% Show filter expression
      obj.updateFilterExpression(hObject);
    end
    
    %----- Clear filter selections
    function clearFilterValues(obj, hObject, event)
      set(hObject, 'Value', 0, 'ForegroundColor', AnimalOverview.CLR_NOTUSED);
      obj.updateFilterExpression(hObject);
    end

    %----- Update the selection criteria for data filters
    function updateFilterExpression(obj, hObject)
      name        = get(hObject, 'UserData');
      name        = name{1};
      expr        = obj.composeFilterExpression(obj.lst.(name));
      compose     = get(obj.btn.(name), 'UserData');
      compose     = FilterState.expression(compose{2});
      expr        = strjoin(expr, [' ' compose ' ']);
      set(obj.edt.(name), 'String', expr, 'UserData', expr, 'BackgroundColor', [1 1 1]);
    end
    
    %----- Convert filter selections to an eval-able string
    function expr = composeFilterExpression(obj, hFilter)
      hFilter( ~strcmpi(get(hFilter,'Enable'), 'on') )      = [];
      hFilter( arrayfun(@(x) get(x,'Value')==0, hFilter) )  = [];
      
      expr            = {};
      for iFilter = 1:numel(hFilter)
        info          = get(hFilter(iFilter), 'UserData');
        values        = info{4};
        if info{3}.isNumeric
          brackets    = '[]';
        else
          brackets    = '{}';
        end
        
        %% Special treatment for user-entered formula
        for iVal = numel(values):-1:1
          if isempty(strfind(values{iVal}, AnimalOverview.MAGIC_VARIABLE))
            continue;
          end
          expr{end+1} = ['(' strrep(values{iVal}, AnimalOverview.MAGIC_VARIABLE, info{2}) ')'];
          values(iVal)= [];
        end
        if isempty(values)
          continue;
        end

        %% Deal with numeric vs. character data
        if ~info{3}.isNumeric
          values      = strcat({''''}, values, {''''});
        end
        expr{end+1}   = sprintf('ismember(%s,%s%s%s)', info{2}, brackets(1), strjoin(values,','), brackets(2));
      end
    end
    
    
    %----- Copy the selected magic variable to clipboard
    function copyMagicVariable(obj, hObject, event)
      index     = get(hObject,'Value');
      if index < 2
        return;
      end
      list      = get(hObject,'UserData');
      clipboard('copy', list{index-1});
    end
    

    %----- Apply preset category settings
    function applyPresetCategories(obj, hObject, event)
      
      %% Get and apply the desired preset settings
      iPreset           = get(hObject, 'Value');
      if iPreset < 2    % First line is a header
        return;
      end
      preset            = AnimalOverview.PRESET_CATEGORIES{iPreset-1, 2};
      obj.applyCategories(preset);
      
    end
    
    %----- Apply the given category settings
    function applyCategories(obj, preset)
      
      %% Loop over category buttons and set to the desired values
      for iCat = 1:numel(obj.lst.categorization)
        info            = get(obj.lst.categorization(iCat), 'UserData');
        iSetting        = find(strcmp(preset(:,1), info{1}));
        if isempty(iSetting)
          value         = DisplayAs.None;
        else
          value         = preset{iSetting,2};
        end
        AnimalOverview.toggleCategorizations(obj.lst.categorization(iCat), [], 1, value);
      end
      
    end
    
    %----- Apply the given filter settings
    function applyFilters(obj, preset)
      
      %% Loop over filter buttons and set to the desired values
      for iFilter = 1:numel(obj.lst.filter)
        info            = get(obj.lst.filter(iFilter), 'UserData');
        iSetting        = find(strcmp(preset(:,1), info{2}));
        if isempty(iSetting)
          set(obj.lst.filter(iFilter), 'Value', 0, 'ForegroundColor', AnimalOverview.CLR_NOTUSED);
        else
          info{4}       = preset{iSetting,3};
          set(obj.lst.filter(iFilter), 'UserData', info, 'Value', 1, 'ForegroundColor', AnimalDatabase.CLR_SELECT);
        end
      end
      
    end
    
    %----- Save the currently set filters and categories
    function saveConfiguration(obj, hObject, event)
      
      %% Get the list of set filters 
      filters                     = cell(0,3);
      for iFilter = 1:numel(obj.lst.filter)
        if get(obj.lst.filter(iFilter), 'Value') == 0
          continue;
        end
        info                      = get(obj.lst.filter(iFilter), 'UserData');
        filters{end+1,1}          = info{2};
        filters{end,2}            = info{3}.identifier;
        filters{end,3}            = info{4};
      end
      
      expression                  = strtrim(get(obj.edt.filter, 'String'));
      filterLogic                 = get(obj.btn.filter, 'UserData');
      filterLogic                 = filterLogic{2};
      
      %% Get the list of active categories
      categories                  = cell(0,2);
      catLabels                   = repmat({{}}, size(DisplayAs.all()));
      for iCat = 1:numel(obj.lst.categorization)
        if get(obj.lst.categorization(iCat), 'Value') == 0
          continue;
        end
        info                      = get(obj.lst.categorization(iCat), 'UserData');
        categories{end+1,1}       = info{1};
        categories{end,2}         = info{2};
        catLabels{info{2}}{end+1} = info{1}(strfind(info{1},'.') + 1:end);
      end
      catLabels                   = cellfun(@(x) strjoin(x,','), catLabels, 'UniformOutput', false);
      
      %% Load existing settings, if any
      if exist(AnimalOverview.PRESET_SAVEFILE, 'file')
        load(AnimalOverview.PRESET_SAVEFILE, 'config');
        saveMode                  = {'-append'};
      else
        config                    = struct('description',{}, 'expression',{}, 'filters',{}, 'categories',{});
        saveMode                  = {};
      end
      
      %% Prompt user for a descriptive title
      if isempty(filters) && isempty(expression) && isempty(categories)
        description               = '';
      else
        description               = [ strjoin(filters(:,2), [' ' FilterState.expression(filterLogic) ' '])                ...
                                    , ' | ', strjoin(catLabels, ' / ')                                                    ...
                                    ];
        description               = validatedInputDialog( 'Save Configuration', 'Configuration title:', description       ...
                                                        , @nonEmptyInputValidator, {@notInListConfirmation, {config.description}, 'A configuration with this title already exists. Overwrite?'}  ...
                                                        , true, AnimalDatabase.GUI_FONT, [], AnimalOverview.GUI_MONITOR   ...
                                                        );
      end
      
      if isempty(description)
        set(hObject, 'BackgroundColor', AnimalDatabase.CLR_ALERT, 'ForegroundColor', [1 1 1]);
        drawnow;
        pause(0.2);
        set(hObject, 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED, 'ForegroundColor', [0 0 0]);
        drawnow;
        return;
      end
      
      %% Save and indicate by button color 
      index                       = find(strcmp({config.description}, description));
      if isempty(index)
        index                     = numel(config) + 1;
      end
      config(index).description   = description;
      config(index).filters       = filters;
      config(index).filterLogic   = filterLogic;
      config(index).expression    = expression;
      config(index).categories    = categories;
      save(AnimalOverview.PRESET_SAVEFILE, saveMode{:}, 'config');
      
      set(hObject, 'BackgroundColor', AnimalDatabase.CLR_ALLSWELL, 'ForegroundColor', [1 1 1]);
      drawnow;
      pause(0.2);
      set(hObject, 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED, 'ForegroundColor', [0 0 0]);
      drawnow;
      
    end
    
    %----- Load a previously saved list of filters and categories
    function loadConfiguration(obj, hObject, event)
      
      %% Prompt user to load a setting from a saved list
      if exist(AnimalOverview.PRESET_SAVEFILE, 'file')
        load(AnimalOverview.PRESET_SAVEFILE, 'config');
        description               = listInputDialog ( 'Load Configuration', 'Select a configuration to load:'           ...
                                                    , {config.description}, {false,{config.expression}}, false, true    ...
                                                    , AnimalDatabase.GUI_FONT, [], AnimalOverview.GUI_MONITOR           ...
                                                    );
      else
        description               = '';
      end
      
      if isempty(description)
        set(hObject, 'BackgroundColor', AnimalDatabase.CLR_ALERT, 'ForegroundColor', [1 1 1]);
        drawnow;
        pause(0.2);
        set(hObject, 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED, 'ForegroundColor', [0 0 0]);
        drawnow;
        return;
      end
      
      %% Load and indicate by button color 
      index                       = find(strcmp({config.description}, description));
      set(hObject, 'BackgroundColor', AnimalDatabase.CLR_ALLSWELL, 'ForegroundColor', [1 1 1]);
      drawnow;
      pause(0.2);
      set(hObject, 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED, 'ForegroundColor', [0 0 0]);
      drawnow;

      
      %% Set the list of set filters 
      obj.toggleFilterState(obj.btn.filter, [], -1, config(index).filterLogic);
      obj.applyFilters(config(index).filters);
      
      expression                  = get(obj.edt.filter, 'String');
      set(obj.edt.filter, 'String', config(index).expression, 'UserData', expression);
      AnimalOverview.flagUserEdit(findjobj(obj.edt.filter), struct('getKeyChar',{''}), obj.edt.filter);
      
      %% Set the list of active categories
      obj.applyCategories(config(index).categories);
      
    end
    
    
    %----- Create performance plots for the currently configured selections
    function generatePlots(obj, hObject, event)

      set(obj.figGUI, 'Pointer', 'watch');
      drawnow;

      %% Get the plotting function to be used
      plotFcn                       = get(obj.lst.plotType, 'UserData');
      plotFcn                       = plotFcn{ get(obj.lst.plotType, 'Value') };
      
      %% Apply data selection filters
      animal                        = obj.animal;
      log                           = obj.log;
      magic                         = obj.magic;
      select                        = strtrim(get(obj.edt.filter, 'String'));
      if ~isempty(select)
        select                      = eval(select);
        animal                      = structfun(@(x) x(select), animal, 'UniformOutput', false);
        log                         = structfun(@(x) x(select), log   , 'UniformOutput', false);
      end
      
      %% Divide data into row/column/color categories for plotting
      catExpr                       = repmat({{}}, 1, numel(DisplayAs.all()));
      category                      = catExpr;
      for iType = 1:numel(obj.lst.categorization)
      	if get(obj.lst.categorization(iType),'Value') ~= 1
          continue;
        end
        
        %% Construct tables with each category being a column
        info                        = get(obj.lst.categorization(iType), 'UserData');
        values                      = eval(info{1});
        if info{4}.isNumeric
          values                    = arrayfun(@(x) obj.dbase.applyFormat(x,info{4}.data,true), values, 'UniformOutput', false);
        end
        catExpr{info{2}}{end+1}     = info{1};
        category{info{2}}(:,end+1)  = values;
      end
      
      %% Construct selections for unique categories and their labels
      catLabel                      = repmat({{}}, size(category));
      catIndex                      = cell(size(category));
      for iType = 1:numel(category)
        [numIndex, values]          = asortIndex(category{iType});
        [valIndex,~,catIndex{iType}]= unique(numIndex, 'rows');
        labels                      = cell(size(valIndex));
        if iType == DisplayAs.Color
          for iCond = 1:numel(values)
            labels(:,iCond)         = values{iCond}(valIndex(:,iCond));
          end
          for iCat = 1:size(valIndex,1)
            catLabel{iType}{end+1}  = strjoin(labels(iCat,:), '; ');
          end
        else
          for iCond = 1:numel(values)
            labels(:,iCond)         = strcat(catExpr{iType}{iCond}, {' = '}, values{iCond}(valIndex(:,iCond)));
          end
          for iCat = 1:size(labels,1)
            catLabel{iType}{end+1}  = labels(iCat,:);
          end
        end
        
        %% Always have at least one category which includes everything
        if isempty(catLabel{iType})
          catLabel{iType}{end+1}    = '';
          catIndex{iType}           = ones(numel(log.date),1);
        end
      end

      %% Decide between grid or flow layout
      heights                       = [];
      widths                        = [];

      nHeaderLines                  = max(1 + cellfun(@(x) numel(strfind(x,'<br/>')), catLabel{DisplayAs.Col}));
      hasColors                     = any(~cellfun(@isempty, catLabel{DisplayAs.Color}));
      hasRows                       = any(~cellfun(@isempty, catLabel{DisplayAs.Row}));
      hasCols                       = any(~cellfun(@isempty, catLabel{DisplayAs.Col}));
      flowLayout                    = (~hasRows || ~hasCols) && (hasRows || hasCols);
      if flowLayout && ~hasCols
        swap                        = [DisplayAs.Row, DisplayAs.Col];
        catLabel(swap)              = catLabel(flip(swap));
        catIndex(swap)              = catIndex(flip(swap));
        hasCols                     = true;
        hasRows                     = false;
      end
      
      %% Clear current plots and prepare some formatting options
      delete(get(obj.cnt.plots, 'Children'));
      set(obj.cnt.plots, 'Visible', 'off');

      aspectRatio                   = AnimalOverview.getEnteredNumber(obj.edt.aspectRatio, 1);
      minPlotSize                   = AnimalOverview.getEnteredNumber(obj.edt.plotSize   , AnimalOverview.DEFAULT_PLOTSIZE);
      
      if aspectRatio > 1
        plotHeight                  = minPlotSize;
        plotWidth                   = plotHeight * aspectRatio;
      else
        plotWidth                   = minPlotSize;
        plotHeight                  = plotWidth / aspectRatio;
      end
      plotWidth                     = plotWidth  + AnimalOverview.MARGIN_PLOTWIDTH;
      plotHeight                    = plotHeight + AnimalOverview.MARGIN_PLOTHEIGHT;
      if ~hasColors
        colors                      = [0 0 0];
      elseif numel(catLabel{DisplayAs.Color}) > 12
        colors                      = linspecer(numel(catLabel{DisplayAs.Color}), 'sequential');
        colors                      = bsxfun(@times, rgb2hsv(colors), [1 1.3 0.85]);
        colors                      = hsv2rgb(min(1,colors));
      elseif numel(catLabel{DisplayAs.Color}) > 7
        colors                      = linspecer(numel(catLabel{DisplayAs.Color}), 'qualitative');
        colors                      = bsxfun(@times, rgb2hsv(colors), [1 1.5 0.85]);
        colors                      = hsv2rgb(min(1,colors));
      else
        colors                      = lines(numel(catLabel{DisplayAs.Color}));
      end
      
      if flowLayout
        extents                     = get(obj.cnt.plots, 'Position');
        numPlots                    = numel(catLabel{DisplayAs.Row}) * numel(catLabel{DisplayAs.Col});
        numRows                     = floor( ( extents(4) - AnimalDatabase.GUI_BORDER )                                               ...
                                           / ( plotHeight + AnimalOverview.HEADER_HEIGHT*nHeaderLines + AnimalDatabase.GUI_BORDER )   ...
                                           );
        numRows                     = min(numRows, numPlots);
        numCols                     = ceil(numPlots / numRows);
      end

      %% Create row headers if nontrivial
      if hasRows && ~flowLayout
        if hasCols
          uix.Empty( 'Parent', obj.cnt.plots );         % corner
        end
        widths(end+1)               = AnimalOverview.HEADER_WIDTH;
        for iRow = 1:numel(catLabel{DisplayAs.Row})
          uicontrol ( 'Parent'          , obj.cnt.plots                             ...
                    , 'Style'           , 'text'                                    ...
                    , 'String'          , catLabel{DisplayAs.Row}{iRow}             ...
                    , 'FontSize'        , AnimalDatabase.GUI_FONT                   ...
                    , 'FontWeight'      , 'bold'                                    ...
                    , 'BackgroundColor' , AnimalDatabase.CLR_GUI_BKG                ...
                    );
        end
      end
        
      %% Generate a grid of plots, column-wise
      template                      = obj.tmplLog;
      for iCol = 1:numel(catLabel{DisplayAs.Col})
        for iRow = 1:numel(catLabel{DisplayAs.Row})
          %% Create column headers if nontrivial
          if flowLayout || (hasCols && iRow == 1)
            if flowLayout || iCol == 1
              heights(end+1)        = AnimalOverview.HEADER_HEIGHT * nHeaderLines;
            end
            uicontrol ( 'Parent'          , obj.cnt.plots                             ...
                      , 'Style'           , 'text'                                    ...
                      , 'String'          , catLabel{DisplayAs.Col}{iCol}             ...
                      , 'FontSize'        , AnimalDatabase.GUI_FONT                   ...
                      , 'FontWeight'      , 'bold'                                    ...
                      , 'BackgroundColor' , AnimalDatabase.CLR_GUI_BKG                ...
                      );
          end
        
          %% Create an axes for this plot
          cntPlot                   = uicontainer( 'Parent', obj.cnt.plots, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
          axs                       = axes( 'Parent'        , cntPlot                     ...
                                          , 'FontSize'      , AnimalDatabase.GUI_FONT     ...
                                          , 'Box'           , 'on'                        ...
                                          );
          hold(axs, 'on');
          
          if exist('enhanceCopying', 'file')
            enhanceCopying(axs);
          end
          
          %% Generate individual lines for color categories
          hPlot                     = gobjects(size(catLabel{DisplayAs.Color}));
          for iClr = 1:numel(catLabel{DisplayAs.Color})
            %% Select data corresponding to this combination of categories
            select                  = catIndex{DisplayAs.Col}   == iCol       ...
                                    & catIndex{DisplayAs.Row}   == iRow       ...
                                    & catIndex{DisplayAs.Color} == iClr       ...
                                    ;
            data                    = structfun(@(x) x(select), log, 'UniformOutput', false);
            hPlot(iClr)             = plotFcn(axs, data, colors(iClr,:), template);
            template                = [];
          end
          
          %% Create legend
          valid                     = ishghandle(hPlot);
          if hasColors && any(valid)
            hLegend                 = legend(hPlot(valid), catLabel{DisplayAs.Color}(valid), 'Location', 'best');
          end
          if flowLayout || iCol == 1
            heights(end+1)          = plotHeight;
          end
        end
      end
      

      %% Format grid layout
      if flowLayout
        widths                      = [widths, plotWidth  * ones(1,numCols)];
        heights                     = heights(1:2*numRows);
      else
        widths                      = [widths, plotWidth  * ones(1,numel(catLabel{DisplayAs.Col}))];
%       heights                       = [heights, plotHeight * ones(1,numel(catLabel{DisplayAs.Row}))];
      end
      set(obj.cnt.plots, 'Widths', widths, 'Heights', heights);
      set(obj.cnt.plotScroll, 'MinimumHeights', sum(heights) + (numel(heights)+1)*AnimalDatabase.GUI_BORDER, 'MinimumWidths', sum(widths) + (numel(widths)+1)*AnimalDatabase.GUI_BORDER);
      
      %% Restore non-busy cursor
      set(obj.cnt.plots, 'Visible', 'on');
      set(obj.figGUI, 'Pointer', 'arrow');
      
    end

  end

  %_________________________________________________________________________________________________
  methods
    
    %----- Create an instance that can then be used to interface with the database
    function obj = AnimalOverview(animalDatabase)
      obj.dbase       = animalDatabase;
    end
    
    %----- destructor, for termination
    function delete(obj)
      obj.closeGUI();
    end

    
    %----- Display a GUI for viewing performance plots
    function gui(obj, researcherID)
      
      %% If no researcher list is provided, default to all
      if nargin < 2 || isempty(researcherID)
        overview          = obj.dbase.pullOverview();
        researcherID      = {overview.Researchers.ID};
      elseif ischar(researcherID)
        researcherID      = {researcherID};
      end
      
      %% Retrieve logs for all animals of the listed researchers
      logs                = cell(size(researcherID));
      animals             = cell(size(researcherID));
      for iID = 1:numel(researcherID)
        [logs{iID}, animals{iID}]               ...
                          = obj.dbase.pullDailyLogs(researcherID{iID});
        animals{iID}      = obj.dbase.whatIsThePlan(animals{iID});
      end
      
      [obj.animal, obj.log, obj.tmplAnimal, obj.tmplLog]    ...
                          = obj.flattenData([animals{:}], [logs{:}], obj.dbase.tmplAnimal, obj.dbase.tmplDailyInfo);
                        
      %% Define magic variables to be used for filtering here
      obj.magic           = struct();
      obj.magic.today     = AnimalDatabase.datenum2date(now());
      
      %% Layout the GUI display
      obj.layoutGUI();
      set(obj.figGUI, 'Visible', 'on');
      
    end
    
    %----- Close the GUI figure 
    function closeGUI(obj, handle, event)
      if ishghandle(obj.figGUI)
        delete(obj.figGUI);
      end
      
      obj.figGUI              = gobjects(0);

      %% Use class metadata to select GUI element containers
      metadata                = metaclass(obj);
      for iProp = 1:numel(metadata.PropertyList)
        property    = metadata.PropertyList(iProp);
        if ~property.Transient || strcmpi(property.GetAccess,'public') || ~isstruct(obj.(property.Name))
          continue;
        end
        for field = fieldnames(obj.(property.Name))'
          obj.(property.Name).(field{:})  = gobjects(0);
        end
      end
    end
    
  end
  
end
