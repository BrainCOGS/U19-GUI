% ANIMALDATABASE  Database of researcher/animal lists, backed by Google spreadsheets.
%
% A database of responsibles and their mice are kept in Google spreadsheets, from which data can be
% pulled/pushed using this class as an interface. The list of all people/animals are kept in the
% spreadsheet indicated by AnimalDatabase.DATABASE_ID, so for example if you use this URL to
% access your database:
%     https://docs.google.com/spreadsheets/d/ABCDE/edit#gid=1296553442
% then you should edit AnimalDatabase.m such that:
%     DATABASE_ID = 'ABCDE'  
%
% Furthermore, the daily logs for individual mice are kept in one spreadsheet per researcher (who is
% the primary responsible for those mice). For now when adding a researcher, one has to manually
% create one spreadsheet and link it into the DATABASE_ID spreadsheet. See instructions in that
% spreadsheet for how to do this.
%
% The rest of the interface allows for programmatic access and update of the contained data. In your
% program you should first create an instance of the database to interact with:
%       dbase     = AnimalDatabase();                       % keep this object around for communications
%       dbase.gui();                                        % user interface from which one can add/view animals
%
% There are a series of "pull*" functions to retrive info at various levels:
%       [people, templates] = dbase.pullOverview();
%       animals   = dbase.pullAnimalList();                 % all researchers
%       animals   = dbase.pullAnimalList('sakoay');         % a single researcher with ID = sakoay
%       logs      = dbase.pullDailyLogs('sakoay');          % all animals for sakoay
%       logs      = dbase.pullDailyLogs('sakoay','k62');    % a particular animal ID for sakoay
%
% To write data to the database, use the following "push*" functions:
%       dbase.pushAnimalInfo('sakoay', 'k62', 'received', 1.3, 'weight', 22.5);
%       dbase.pushDailyInfo('sakoay', 'k62', 'received', 1.3, 'weight', 22.5);
%
% The pull* functions do not create new sheets, e.g. will return empty results in the case of a
% newly introduced researcher or animal. The "push*" functions will create sheets as necessary to
% ensure that data can be written. You can also use the low-level "open*" functions which only
% checks for and creates such sheets without pushing specific data.
%
% Remote access to Google spreadsheets can be quite slow. However because multiple machines can
% write to the spreadsheets at about the same time, all functions that do things like create a new
% sheet must check the current state of the database before doing so. To minimize pinging, pull* and
% push* functions will only ask for overview-level data when neccessary. For example, if the user
% calls pullAnimalList() with a specific user, then it is assumed that the user should already be in
% the cached Researchers list (otherwise where did the user ID come from?). This is as opposed to
% when pullAnimalList() is called without arguments, in which case an updated list of researchers
% is obtained by (internally) calling pullOverview().
%
% ------------------------------
%   Data format specifications
% ------------------------------
%
% Both the animal list and daily information databases are tables where columns correspond to
% variables (e.g. animal ID, weight, etc.) and rows correspond to instances (e.g. various mice in a
% cohort, or for the daily data, each day). Each column/variable has a fixed data type (which
% specifies what are allowed values) and is configured via the "template" sheet in the main
% spreadsheet (AnimalDatabase.DATABASE_ID). 
%
% The data type specifier is a string with 3 components, the 3rd piece being optional:
%     (entered/calculated)   (format)   [=  (default)]
%     --------- 1 --------   --- 2 --   ------ 3 -----
%
% The 1st component can have values:
%     '>'   = can be freely edited by the user, as long as it satisfies the required format
%     ':'   = calculated or otherwise program-controlled data that can only be viewed by the user
%
% The 2nd component defines parsing rules and are best understood from reading the "*Format()"
% functions. The available options at the time of this writing are:
%     '%s'  = an arbitrary string
%     '%f'  = a floating-point number; similarly most printf specifiers can be used, like '%d' for
%             integer data
%     '?X'  = where X is the name of a Matlab enumerated type (a classdef which defines enumeration
%             values); this restricts the data to the possible enumeration values, which are entered
%             in the database as their string names
%     '#X'  = the same as '?X', except that instead of a single entry this assumes a 7-element array
%             of entries corresponding to the 7 days of the week (see AnimalDatabase.DAYS_OF_WEEK)
%     '@X'  = a scalar struct with simple numeric fields, as defined in the template spreadsheet
%     '*X'  = a string that can be populated either free-form or from tmplX.value
% The following are specially parsed formats:
%     'DATE'  = [year, month, day] via the Matlab interface, 'month/day/year' via the Google web
%               interface (this is translated upon pull/push of data)
%     'TIME'  = HHMM in 24-hour format; note that this is stored as a 1-4 digit number
%     'IMAGE' = an RGB image encoded in printable ASCII characters via base64 encoding
%
% The 3rd component of the data type specifier defines the default value in the case of entered
% quantities, or provides a formula for computing calculated quantities. Note that the only place
% where default values for entered quantities appear are in the Matlab-based GUI, when the user is
% prompted to input information e.g. when adding a new animal. The GUI will not write to the
% database a default value unless it has been approved by the user. Calculated quantities have
% almost the same treatment --- typically they are calculated in a user session, in which case
% they use the current values of whatever other variables that they depend on, and once written to
% the database they will not be recalculated in the future. There is no mechanism for redacting logs
% short of via the Google spreadsheet web interface.
%
classdef AnimalDatabase < handle
  
  %_________________________________________________________________________________________________
  properties (Constant)
    CLIENT_ID             = getfield(load('database_config.mat'), 'client_id')
    CLIENT_SECRET         = getfield(load('database_config.mat'), 'client_secret')
    GOOGLE_URL            = 'https://www.google.com'
    GOOGLESHEETS_URL      = 'https://docs.google.com/spreadsheets/d'
    EDIT_FORMAT           = '%s/%s/edit#gid=%s'
    EXPORT_FORMAT         = '%s/%s/export?format=csv&gid=%s'
    
    FIRST_SHEET           = '0'
    DATABASE_ID           = getfield(load('database_config.mat'), 'database_id')
    UPDATE_PERIOD         = 10
    UPDATE_PERIOD_SCALE   = 0.3
    NUM_POLLS_SCALE       = 3
    
    NUMBER_FORMAT         = '%.4g'
    DATE_FORMAT           = '%d/%d/%d'
    DATE_DISPLAY          = 'dd mmm yyyy, HH:MM:SS pm'
    DAYS_OF_WEEK          = {'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'}     % N.B. must match weekday() order

    
    ALLOW_RECORDS_LAPSE   = true
    ANI_HOME              = 'vivarium'
    ANI_GRAVEYARD         = '(grave)'
    ANI_ENDLOC            = 'valhalla'
    EMERGENCY_STATUS      = [HandlingStatus.Missing, HandlingStatus.Dead];
    
    MAX_WEIGHT_DIFFERENCE = 0.2                           % maximum difference in weight w.r.t. initial for same-mouse check
    MAX_ANI_GROUP         = 5                             % maximum number of mice per cage
    ANI_IMAGE_SIZE        = [32 32]
    ANI_ID_INFO           = {'effective'}
    MAX_ENTRIES_PER_ROW   = 3

    
    SPECS_DATE            = regexp(': DATE', AnimalDatabase.RGX_FIELD_FORMAT, 'tokens', 'once')
    SPECS_TIME            = regexp(': TIME', AnimalDatabase.RGX_FIELD_FORMAT, 'tokens', 'once')
    SPECS_YESNO           = regexp(': ?YesNoMaybe', AnimalDatabase.RGX_FIELD_FORMAT, 'tokens', 'once')
    SPECS_TEXT            = regexp(': %s', AnimalDatabase.RGX_FIELD_FORMAT, 'tokens', 'once')
    SPECS_STRINGS         = regexp(': {%s}', AnimalDatabase.RGX_FIELD_FORMAT, 'tokens', 'once')
    SPECS_INTEGER         = regexp(': %d', AnimalDatabase.RGX_FIELD_FORMAT, 'tokens', 'once')

    RGX_DOC_URL           = '^https?://.+/([^/#&?]+)(/[^/]+)?$'
    RGX_FIELD_NAME        = '^\s*\|\|\s*(.+)'
    RGX_FIELD_FORMAT      = '^\s*([>:])\s*([^=]+?)\s*(=\s*.+)?\s*$'
    RGX_MULTI_FORMAT      = '^\s*{\s*(.*?)\s*}\s*$'
    RGX_ARRAY_FORMAT      = '^\s*\[\s*(.*?)\s*\]\s*$'
    RGX_IMG_FORMAT        = '^([0-9]+)x([0-9]+)\[(.*)\]$'
    RGX_VARIABLE          = '(\$[a-zA-Z_]\w*)\>'
    RGX_PRECISION         = '%[0-9]*[.]?[0-9]*'
    RGX_NOTATED           = '^\s*\[([^\]]+)\]\s+(.+)$'
    RGX_HTMLBODY          = '^\s*<\s*[hH][tT][mM][lL]\s*>\s*(.*)\s*<\s*/\s*[hH][tT][mM][lL]\s*>\s*$'
    

    GUI_TITLE             = 'BRAIN Mice'
    GUI_MONITOR           = AnimalDatabase.getGUIMonitor()
    GUI_IS_SMALLSCREEN    = AnimalDatabase.checkMonitorSize()
    GUI_POSITION          = [0 45 -1 -45]
%     GUI_POSITION          = [0 45 1200 800]
    GUI_FONT              = conditional(AnimalDatabase.GUI_IS_SMALLSCREEN, 9, 14)
    GUI_BTNSIZE           = conditional(AnimalDatabase.GUI_IS_SMALLSCREEN, 30, 40)
    GUI_BORDER            = conditional(AnimalDatabase.GUI_IS_SMALLSCREEN, 2, 5)
    GUI_HEADER            = 150
    GUI_MARKERSIZE        = 4

    CLR_GUI_BKG           = [1 1 1]*0.97;
    CLR_SEL_BKG           = [1 1 1]*0.95;
    CLR_BUSY              = [217 227 152]/255;
    CLR_SELECT            = [0 0 1];
    CLR_NOTSELECTED       = [1 1 1]*0.94;
    CLR_ALERT             = [1 0 0];
    CLR_ALLSWELL          = [99 161 0]/255;
    CLR_TECHNICIAN        = [173 222 255]/255;
    CLR_RESEARCHER        = [213 199 255]/255;
    CLR_ADD_BTN           = [222 212 191]/255;
    CLR_DISABLED_BKG      = [1 1 1]*0.8;
    CLR_DISABLED_TXT      = [1 1 1]*0.5;

    DIR_IMAGES            = fullfile(fileparts(mfilename('fullpath')), 'images')
    DIR_ANIIMAGE          = fullfile(AnimalDatabase.DIR_IMAGES, 'animals')
    IMAGE_CANDY           = AnimalDatabase.loadGUIImage ( fullfile(AnimalDatabase.DIR_IMAGES, {'stacks.tif','experiment.tif','mouses.tif'}) ...
                                                        , AnimalDatabase.CLR_GUI_BKG, [true false true]                                     ...
                                                        );
  end
  
  %_________________________________________________________________________________________________
  properties (Access = protected, Transient)
    httpHandler
    
    figGUI      = gobjects(0)
    figCheckout = gobjects(0)
    figPerform  = gobjects(0)
    
    cio         = struct()
    pfm         = struct()

    cnt         = struct()
    pnl         = struct()
    btn         = struct()
    lst         = struct()
    tbl         = struct()
    axs         = struct()
    plt         = struct()
    
    tmrRightNow         = []
    tmrPollScale        = []
    scaleReading        = nan
    imBusy              = false
  end
  
  %_________________________________________________________________________________________________
  properties (SetAccess = protected)
    whoAmI
    dbStructure
    eScale
    
    %% Structures added to the "Responsibles" sheet must be added here
    DutyRoster
    Technicians
    Researchers
    NotificationSettings
    
    %% Structures added to the "template" sheet must be added here with a "tmpl" prefix
    tmplAnimal
    tmplDailyInfo
    tmplRightNow
    tmplActionItems
    tmplGenotype
  end  
  
  %_________________________________________________________________________________________________
  methods (Static)
    
    %----- Load a series of overlaid images with transparency w.r.t. the desired background
    function monitor = getGUIMonitor()
      try
        monitor = RigParameters.guiMonitor;
      catch
        monitor = getMonitorBySize(false);
      end
    end
    
    %----- Returns true if the screen size is smaller than a given area in pixels
    function isSmall = checkMonitorSize()
      monitors        = get(0,'monitor');
      screenArea      = prod( monitors(:,3:end), 2 );
      isSmall         = screenArea(AnimalDatabase.GUI_MONITOR) < 1920*1080;
    end
    

    %----- Load a series of overlaid images with transparency w.r.t. the desired background
    function img = loadGUIImage(imgFile, bkgColor, antialias)
      if nargin < 3 || isempty(antialias)
        antialias   = true(size(imgFile));
      elseif numel(antialias) == 1
        antialias   = repmat(antialias, size(imgFile));
      end
      
      img           = [];
      for iFile = 1:numel(imgFile)
        %% Load the source image and use the first encountered size
        source      = imread(imgFile{iFile});
        if isempty(img)
          img       = repmat(reshape(255*bkgColor,1,1,[]), size(source,1), size(source,2));
        end
        
        %% Add to the current image using the 4th channel as the alpha value
        alpha       = double(source(:,:,end)) / 255;
        if antialias(iFile)
          alpha     = imgaussfilt(imerode(alpha, strel('square',3)), 1);
        end
        img         = bsxfun(@times,(1-alpha),img) + bsxfun(@times,alpha,double(source(:,:,1:3)));
      end
      img           = uint8(img);
    end

    
    %----- Read all bytes from stream to uint8 (http://stackoverflow.com/a/1323535)
    function out = readStream(inStream)
      import com.mathworks.mlwidgets.io.InterruptibleStreamCopier;
      byteStream  = java.io.ByteArrayOutputStream();
      isc         = InterruptibleStreamCopier.getInterruptibleStreamCopier();
      isc.copyStream(inStream, byteStream);
      inStream.close();
      byteStream.close();
      out         = char(typecast(byteStream.toByteArray', 'uint8'));
    end
    
    
    %----- Add columns to a given field
    function specs = addColumns(specs, field, data)
      for iCol = 1:numel(data)
        if ~isempty(data{iCol})
          specs(iCol).(field) = data{iCol};
        end
      end
    end
    
    %----- Construct an empty struct with the given fields
    function empty = emptyLike(template, initValue)
      if nargin < 2
        initValue       = {};
      end
      
      empty             = {template.identifier};
      [empty{end+1,:}]  = deal(initValue);
      empty             = struct(empty{:});
    end
    
    %----- Convert serial date number [e.g. from now()] to yyyymmdd format
    function yyyymmdd = datenum2date(when)
      if nargin < 1
        when    = now();
      end
      switch numel(when)
        case 1
          when  = datevec(when);
        case 3
        case 6
        otherwise
          error('AnimalDatabase:datenum2date', 'when must either be a serial date number e.g. as returned by now(), or a date vector as returned by clock().');
      end
      yyyymmdd      = when(1)*10000 + when(2)*100 + when(3);
    end
    
    %----- Convert serial date number [e.g. from now()] to HHMM format
    function hhmm = datenum2time(when)
      if nargin < 1
        when    = now();
      end
      switch numel(when)
        case 1
          when  = datevec(when);
        case 2
          when  = [0 0 0 when];
        case 6
        otherwise
          error('AnimalDatabase:datenum2time', 'when must either be a serial date number e.g. as returned by now(), or a date vector as returned by clock().');
      end
%       hhmm      = when(4:5);
      hhmm      = when(4)*100 + when(5);
    end
    
    %----- Convert HHMM to a fraction of a day
    function number = time2days(when)
      switch numel(when)
        case 1
          when  = AnimalDatabase.num2time(when);
        case 2
        otherwise
          error('AnimalDatabase:time2days', 'when must either be a HHMM number or an array [HH, MM].');
      end
      number    = (when(1) + when(2)/60) / 24;
    end
    
    %----- Convert a yyyymmdd format number to [year, month, date]
    function date = num2date(number)
      switch numel(number)
        case 1
          year      = floor(number / 10000);
          number    = number - year * 10000;
          month     = floor(number / 100);
          day       = number - month * 100;
        case 3
          year      = number(1);
          month     = number(2);
          day       = number(3);
        otherwise          
          error('AnimalDatabase:num2date', 'Invalid DATE data, should either be a single yyyymmdd number or a triplet (yyyy,mm,dd).');
      end
      
      if year < 0 || year > 9999 || month > 12 || day > 31
        error('AnimalDatabase:num2date', 'Invalid DATE data %.7g" with year = %.5g, month = %.3g, day = %.3g.', year, month, day);
      end
      date          = [year, month, day];
    end
    
    %----- Convert a HHMM format number to hours and minutes in 24-hour format
    function [hour, minute] = num2time(number)
      switch numel(number)
        case 1
          hour      = floor(number / 100);
          minute    = number - 100*hour;
        case 2
          hour      = number(1);
          minute    = number(2);
        otherwise          
          error('AnimalDatabase:num2time', 'Invalid TIME data, should either be a single HHMM number or a pair (HH,MM).');
      end
      
      if hour < 0 || hour > 23 || minute < 0 || minute > 59 || minute ~= floor(minute)
        error('AnimalDatabase:num2time', 'Invalid TIME data %.4g" with hour = %.3g, minute = %.3g.', number, hour, minute);
      end
    end
    
    
    %----- Parse a data table into structs with rows specifying field names 
    function specs = parseDataSpecs(data)
      %% Loop through rows and detect fields vs. sub-structures
      specs                   = struct();
      subSpecs                = '';
      for iRow = 1:size(data,1)
        if isempty(data{iRow,1})
          continue;
        end
        
        name                  = regexp(data{iRow,1}, AnimalDatabase.RGX_FIELD_NAME, 'tokens', 'once');
        if isempty(name)
          name                = regexprep(data{iRow,1}, '\s', '');
          if isvarname(name)
            subSpecs          = name;
          end
        else
          name                = name{:};
          if isempty(subSpecs)
            specs             = AnimalDatabase.addColumns(specs, name, data(iRow,2:end));
          elseif isfield(specs, subSpecs)
            specs.(subSpecs)  = AnimalDatabase.addColumns(specs.(subSpecs), name, data(iRow,2:end));
          else
            specs.(subSpecs)  = AnimalDatabase.addColumns(struct(), name, data(iRow,2:end));
          end
        end
      end
    end
    
    %----- Find the ID of a sheet with the given title, given sheetData returned by mat2sheets()
    function sheetID = findSheetID(sheetTitle, sheetData, where, who, allowEmpty)
      if nargin < 5 || isempty(allowEmpty)
        allowEmpty        = false;
      end
      if isempty(who)
        who               = '';
      else
        who               = [' for ' who];
      end
      if ischar(sheetTitle)
        sheetTitle        = {sheetTitle};
        singleton         = true;
      else
        singleton         = false;
      end

      sheetProps          = [sheetData.sheets.properties];
      sheetID             = cell(size(sheetTitle));
      for iSheet = 1:numel(sheetTitle)
        index             = find(strcmpi({sheetProps.title}, sheetTitle{iSheet}));
        if numel(index) > 1
          error('AnimalDatabase:findSheetID', 'Multiple information sheets in %s%s found with title "%s".', where, who, sheetTitle{iSheet});
        elseif ~isempty(index)
          sheetID{iSheet} = num2str(sheetProps(index).sheetId);
        elseif ~allowEmpty
          error('AnimalDatabase:findSheetID', 'No sheet in %s%s has title "%s".', where, who, sheetTitle{iSheet});
        end
      end

      if singleton
        sheetID           = sheetID{:};
      end
    end
    
    
    %----- Minimum test for validity of name, value input pairs 
    function pairs = checkPairInput(pairs, what)
      if numel(pairs) == 1 && isstruct(pairs{1})
        names   = fieldnames(pairs{1})';
        values  = struct2cell(pairs{1})';
        pairs   = [names; values];
      elseif mod(numel(pairs), 2) ~= 0
        error('AnimalDatabase:pushDailyInfo', '%s must be specified as one or more identifier, value pairs.', what);
      end
    end
    
    %----- Get sibling uicontrol one column to the left
    function sibling = getSibling(ctrl)
      %% Remember that everything is in reverse order!
      container     = get(ctrl, 'Parent');
      children      = reshape(get(container,'Children'), [], numel(get(container,'Widths')));
      [row,col]     = find(children == ctrl);
      sibling       = children(row, col+1);
    end
    
    %----- Get string value of uicontrol input
    function str = getUIString(ctrl)
      %% Otherwise decide on the string value
      str           = get(ctrl, 'String');
      switch get(ctrl, 'Style')
        case 'text'
          %% Assume that text boxes always have checkbox siblings
          check     = AnimalDatabase.getSibling(ctrl);
          info      = get(check, 'UserData');
          str       = sprintf('[%s]  %s', char(info{3}), char(str));
        case 'edit'
        case 'popupmenu'
          str       = str{get(ctrl, 'Value')};
        case 'listbox'
          if iscell(str)
            str     = strtrim(str);
          end
        case 'pushbutton'
          info      = get(ctrl, 'UserData');
          str       = char(info{3});
        otherwise
          error('AnimalDatabase:getUIString', 'Unsupported uicontrol style "%s".', get(ctrl, 'Style'));
      end
    end
    
    %----- Prompt the user to enter a line either freeform or selected from a list
    function setFromList(hObject, event, title, prompt, list, hTarget)
      answer          = listInputDialog(title, prompt, list, @nonEmptyInputValidator, false, true, AnimalDatabase.GUI_FONT, [], AnimalDatabase.GUI_MONITOR);
      if isempty(answer)
        return;
      end
      set(hTarget, 'String', answer);
    end
    
    %----- Prompt the user to enter a line either freeform or selected from a list
    function addFromList(hObject, event, title, prompt, list, hTarget)
      answer          = listInputDialog(title, prompt, list, @nonEmptyInputValidator, false, true, AnimalDatabase.GUI_FONT, [], AnimalDatabase.GUI_MONITOR);
      if isempty(answer)
        return;
      end
      
      value           = get(hTarget, 'String');
      if isempty(value)
        value         = {answer};
      elseif ischar(value)
        value         = {value, answer};
      else
        value{end+1}  = answer;
      end
      set(hTarget, 'String', value);
    end
    
    %----- Remove the currently selected item from a list
    function removeListEntry(hObject, event, hTarget)
      list            = get(hTarget, 'String');
      index           = get(hTarget, 'Value');
      if isempty(list)
        return;
      end
      list(index)     = [];
      set(hTarget, 'String', list, 'Value', min(index,numel(list)));
    end
    
    
    %----- Get the list of cages for the given animals in natural order
    function [cageName, cageIndex] = getCages(animal)
      if isempty(animal)
        cageName      = {};
        cageIndex     = [];
        return;
      end
      
      [cage,~,iCage]  = unique({animal.cage});
      order           = asort(cage);
      indices         = [order.aix; order.six; order.tix];
      ranks           = nan(size(indices));
      ranks(indices)  = 1:numel(indices);
      cageName        = [order.anr; order.snr; order.str];
      cageIndex       = ranks(iCage);
    end
    
    %----- Checks the rightNow status to determine whether the given animals has been watered/weighed
    function yes = takenCaredOf(animal, thisDate)
      if nargin < 2 || isempty(thisDate)
        thisDate  = AnimalDatabase.datenum2date();
      end
      yes         = arrayfun( @(x)    ~isempty(x.rightNow)              ...
                                  &&  x.rightNow.date == thisDate       ...
                                  &&  isfinite(x.rightNow.received)     ...
                            , animal                                    ...
                            );
    end
    
    
    %----- Restore enabled state of controls and remove keypress traps
    function restoreInteractivity(hObject, ctrlID, ctrlDate)
      if ~isempty(hObject)
        info    = get(hObject, 'UserData');
        set(info{2}(ishghandle(info{2})), 'Enable', 'on');
      end
      if ~isempty(ctrlID)
        set(ctrlID, 'KeyPressFcn', '', 'Callback', '', 'Enable', 'inactive', 'BackgroundColor', EntryState.color(EntryState.DisplayOnly));
      end
      if ~isempty(ctrlDate)
        set(ctrlDate, 'BackgroundColor', EntryState.color(EntryState.DisplayOnly));
      end
    end

    %----- Sets the borders of uicontrols according to their state
    function jObject = setBorderByState(buttons, color, width)
      if nargin < 2
        color         = AnimalDatabase.CLR_SELECT;
      end
      if nargin < 3
        width         = 3;
      end
      
      drawnow;
      for iBtn = 1:numel(buttons)
        if ~ishghandle(buttons(iBtn))
          continue;
        end
        
        info          = get(buttons(iBtn), 'UserData');
        if iscell(info) && numel(info) >= 3
          jObject     = info{3};
        else
          jObject     = findjobj(buttons(iBtn));
        end
        
        if strcmpi(get(buttons(iBtn),'Style'), 'togglebutton') && get(buttons(iBtn),'Value')
          jObject.setBorder(javax.swing.border.LineBorder(java.awt.Color(color(1),color(2),color(3)), width, false));
        elseif strcmpi(get(buttons(iBtn),'Enable'), 'on')
          jObject.setBorder(javax.swing.border.LineBorder(java.awt.Color.lightGray, 1, false));
        else
          jObject.setBorder(javax.swing.border.EmptyBorder(1,1,1,1));
        end
        jObject.repaint();
      end
    end
    
    
    %----- Callback function that emulates disabled mode
    function buttonDisabled(hObject, event)
      set(hObject, 'Value', 0);
    end
    
    
    %----- Set optimal number of rows/columns for a grid of buttons
    function [nRows,nCols] = layoutButtonGrid(hObject, buttonWidth, layoutScroller)
      if nargin < 2 || isempty(buttonWidth)
        buttonWidth           = 4*AnimalDatabase.GUI_BTNSIZE;
      end
      if nargin < 3 || isempty(layoutScroller)
        layoutScroller        = true;
      end
      
      %% Decide the maximum number of columns
      hParent                 = get(hObject,'Parent');
      panelPos                = get(hParent, 'Position');
      maxWidth                = panelPos(3);
      maxCols                 = floor(maxWidth / buttonWidth);
      
      %% Adjust the number of rows to match
      nButtons                = numel(get(hObject, 'Children'));
      nCols                   = min(nButtons, maxCols);
      nRows                   = ceil(nButtons / nCols);
      nCols                   = ceil(nButtons / nRows);
      panelHeight             = nRows * 1.6*AnimalDatabase.GUI_BTNSIZE + (nRows+2)*AnimalDatabase.GUI_BORDER;

      %% Set grid sizes to have fixed-width buttons
      set(hObject, 'Widths', repmat(buttonWidth,1,nCols), 'Heights', -ones(1,nRows));
      set(hParent, 'UserData', panelHeight);
      if layoutScroller
        AnimalDatabase.layoutScrollablePanels(get(hParent, 'Parent'));
      end
    end
    
    %----- Set height of panels and scrolling panel constraints
    function layoutScrollablePanels(hObject)
      hPanels                 = get(hObject, 'Children');
      panelHeight             = arrayfun(@(x) get(x,'UserData'), hPanels);

      set( hObject, 'Heights', flip(panelHeight(:)) );
      set(get(hObject,'Parent'), 'MinimumHeights', sum(panelHeight) + numel(hPanels)*AnimalDatabase.GUI_BORDER);
    end

    %----- Rearrange elements to preserve an assumed n-by-2 column uix.Grid
    function mergeTabularGrid(hTable, origRows)
      if origRows < 1
        return;
      end
      elements          = get(hTable,'Children');
      totalRows         = numel(elements) / 2;
      
      %% First we perform a simpler calculation assuming ascending order of displayed elements
      addedRows         = totalRows - origRows;
      origCol1          = 1:origRows;
      origCol2          = origRows + origCol1;
      addCol1           = origCol2(end) + (1:addedRows);
      addCol2           = addedRows + addCol1;

      %% Now account for the inverted display order, i.e. the first element is actually listed as last
      newOrder          = [origCol1, addCol1, origCol2, addCol2];
      newOrder          = 2*totalRows+1 - newOrder;
      newOrder          = flip(newOrder);
      set(hTable, 'Children', elements(newOrder));
    end
    
  end
  
  %_________________________________________________________________________________________________
  methods (Access = protected)
    
    %----- Check if a given database URL is available
    function success = testDataAccess(obj, database, sheet)
      url         = sprintf( AnimalDatabase.EXPORT_FORMAT, AnimalDatabase.GOOGLESHEETS_URL, database, sheet );
      connection  = java.net.URL([], url, obj.httpHandler).openConnection();
      connection.setRequestMethod('HEAD');
      success     = connection.getResponseCode() == 200;
    end
    
    %----- Sets a busy flag and visual indicator that the GUI can't respond right now
    function alreadyBusy = waitImWorking(obj)
      alreadyBusy     = obj.imBusy;
      if alreadyBusy
        return;
      end
      
      obj.imBusy      = true;
      if ~isempty(obj.figGUI) && ishghandle(obj.figGUI)
        set(obj.figGUI, 'Pointer', 'watch');
        set(obj.btn.finalize, 'String', 'Doing something...', 'BackgroundColor', AnimalDatabase.CLR_BUSY);
        drawnow;
      end
    end
    
    %----- Unsets a busy flag and shows a visual indicator that the GUI can accept input now
    function okImDone(obj, alreadyBusy)
      if isequal(alreadyBusy,true)
        return;
      end
      
      obj.imBusy      = false;
      if ~isempty(obj.figGUI) && ishghandle(obj.figGUI)
        set(obj.figGUI, 'Pointer', 'arrow');
        set(obj.btn.finalize, 'String', 'Ready now', 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED);
        drawnow;
      end
    end
    
    
    %----- Reorder rows of a given database by natural order of the given indexing strings
    function order = sortDatabase(obj, data, strIndex, startRow, database, sheet, where, who)
      if size(strIndex,1) ~= size(data,1)
        error('AnimalDatabase:sortDatabase', 'strIndex must have exactly the same number of rows as data.');
      end
      
      %% Obtained a combined sort order and do nothing if it doesn't reorder any elements
      numIndex          = asortIndex(strIndex);
      [~,order]         = sortrows(numIndex);
      if all(order == (1:size(numIndex,1))')
        order           = [];
        return;
      end
      
      %% Upload reordered rows
      data              = data(order,:);
      try
        [~,sheetID]     = mat2sheets(database, sheet, [startRow,1], data);
      catch err
        displayException(err);
        error('AnimalDatabase:sortDatabase', 'Failed to write sorted data into %s (researcher %s).', where, who);
      end
    end
    
    %----- Copy informational formatting from a template to a sheet
    function [info, sheetID] = copyTemplateInfo(obj, template, row, database, sheet, where, who)
      try
        [~,sheetID]     = mat2sheets(database, sheet, [row 1], {template.field});
      catch err
        displayException(err);
        error('AnimalDatabase:copyTemplateInfo', 'Failed to copy template information to %s sheet ID "%s" for %s.', where, sheet, who);
      end
      
      %% Construct empty information struct with the same fields as the template
      info              = AnimalDatabase.emptyLike(template);
    end
    
    %----- Gets structural information about the watering logs of the given researcher
    function [researcher, refreshed, index] = pullLogsStructure(obj, researcher, forceUpdate)
      if ischar(researcher)
        [researcher,index]  = obj.findResearcher(researcher);
      end
      if nargin < 3 || isempty(forceUpdate)
        forceUpdate         = false;
      end
      refreshed             = false;
      
      %% Special case for person without animals, don't require watering logs
      if isempty(researcher.animalsGID)
        if nargout > 2 && ~exist('index', 'var')
          [~,index]         = obj.findResearcher(researcher.ID);
        end
        return;
      end
      
      %% Locate the watering logs spreadsheet, refreshing the overview if necessary
      database              = researcher.wateringLogs;
      if isempty(database)
        obj.pullOverview();
        [researcher,index]  = obj.findResearcher(researcher.ID);
        if isempty(database)
          error('AnimalDatabase:pullLogsStructure', 'Researcher %s does not have a wateringLogs URL specified. Please fix this via the Google Spreadsheets web interface.', researcher.ID);
        end
      end

      %% Retrieve the log structure if necessary
      if isempty(researcher.logStructure) || forceUpdate
        [~,index]           = obj.findResearcher(researcher.ID);
        obj.Researchers(index).logStructure               ...
                            = mat2sheets(database);
        [researcher,index]  = obj.findResearcher(researcher.ID);
        refreshed           = true;
      end
      
      %% Ensure all required outputs
      if nargout > 2 && ~exist('index', 'var')
        [~,index]           = obj.findResearcher(researcher.ID);
      end
    end
    
    %----- Find a particular animal's watering log sheet, refreshing info if necessary
    function [gid, researcher, refreshed, index] = findDailyLogsID(obj, researcher, animalID, allowRefresh, where)
      %% Default arguments
      if nargin < 4 || isempty(allowRefresh)
        allowRefresh        = true;
      end
      if nargin < 5 || isempty(where)
        where               = 'watering logs';
      end
      if ischar(researcher)
        researcher          = obj.findResearcher(researcher);
      end
      
      %% First try to find the desired sheet ID
      gid                   = AnimalDatabase.findSheetID(animalID, researcher.logStructure, where, researcher.Name, true);
      refreshed             = false;
      
      if ~allowRefresh
        %% Accept the current results if refresh is not allowed
        if nargout > 3
          [~,index]         = obj.findResearcher(researcher.ID);
        end
      
      elseif isempty(gid) || ~obj.testDataAccess(researcher.wateringLogs,gid)
        %% Pull logs from remote location if not present or not accessible
        [researcher,index]  = obj.pullLogsStructure(researcher, true);
        refreshed           = true;
        gid                 = AnimalDatabase.findSheetID(animalID, researcher.logStructure, where, researcher.Name, true);
        
      elseif nargout > 3
        [~,index]           = obj.findResearcher(researcher.ID);
      end
    end
    
    
    %----- Create a GUI control based on a given format template
    % Controls are either for display purposes only (inactive) or can be edited by the user. In the
    % latter case they can either currently contain a default value, an invalid user-entered value,
    % or a valid user-entered value. The three states are stored in the UserData field as well as
    % being distinguished by background color.
    function [ctrl, state, height, support] = guiForFormat(obj, parent, template, value, data, origValue, isOwner)
      
      if nargin < 7
        isOwner     = true;
      end
      
      %% For array data, create a single multi-entry uicontrol 
      format        = template.data;
      multiFormat   = regexp(format{2}, AnimalDatabase.RGX_MULTI_FORMAT, 'tokens' ,'once');
      if ~isempty(multiFormat)
        format{2}   = multiFormat{:};
      end
        
      %% For time-based plans, assume that exactly one has been selected prior to this function
      futurePlans   = isfield(template, 'futurePlans') && strcmpi(template.futurePlans, 'yes');
      if futurePlans
        multiFormat = [];
      end
      
      %% Parse format specification to decide on data integrity requirements
      isValid       = true;
      doWeigh       = false;
      isChecks      = strcmp(format{2}, 'CHECK');
      if isequal(format{1}, ':')
        state       = EntryState.DisplayOnly;
        if strcmp(format{3}, 'WEIGH')                   % special treatment for showing a weigh button
          doWeigh   = true;
        elseif isempty(value) && ~isempty(format{3})    % a computed quantity
          value     = obj.suggestedForFormat(format, data);
        end
        
      elseif ~isequal(format{1}, '>')
        error('AnimalDatabase:guiForFormat', 'Unsupported data entered/calculated specifier "%s".', format{1});
        
      elseif futurePlans && ~isOwner                    % some data can only be edited by the animal's owner
        state       = EntryState.DisplayOnly;
        
      elseif      isempty(value)                        ...
              && ~isempty(format{3})                    ... user did not provide a value but there is a recommended default
              && ~isChecks
        state       = EntryState.Suggested;
        value       = obj.suggestedForFormat(format, data);
        
      elseif     ~isfield(template, 'mandatory')        ... anything goes for non-mandatory fields
              || strcmpi(template.mandatory, 'no')
        state       = EntryState.Freeform;
        
      else
        state       = EntryState.Unknown;               % need to check for validity
      end
      
      %% Decide on the type of GUI element to create
      height        = AnimalDatabase.GUI_BTNSIZE;
      support       = gobjects(0);
      if doWeigh
        %% Special case of weight display, which allows the user to start a weighing method
        if ~isempty(multiFormat)
          error('AnimalDatabase:guiForFormat', 'Array data not supported for WEIGH.');
        end
        cntCtrl     = uix.HBox( 'Parent', parent, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        ctrl        = uicontrol ( 'Parent'              , cntCtrl                           ...
                                , 'Style'               , 'edit'                            ...
                                , 'String'              , value                             ...
                                , 'HorizontalAlignment' , 'left'                            ...
                                , 'Interruptible'       , 'off'                             ...
                                , 'BusyAction'          , 'cancel'                          ...
                                );
        obj.btn.weighAni                                                                    ...
                    = uicontrol ( 'Parent'              , cntCtrl                           ...
                                , 'Style'               , 'pushbutton'                      ...
                                , 'String'              , 'Weigh'                           ...
                                , 'TooltipString'       , '<html><div style="font-size:14px">Enter weight and upload logs</div></html>'    ...
                                , 'FontWeight'          , 'bold'                            ...
                                , 'FontSize'            , AnimalDatabase.GUI_FONT           ...
                                , 'UserData'            , ctrl                              ...
                                , 'Interruptible'       , 'off'                             ...
                                , 'BusyAction'          , 'cancel'                          ...
                                );
        set(cntCtrl, 'Widths', [-1, 5*AnimalDatabase.GUI_BTNSIZE]);
        
      elseif isChecks
        %% Tri-state check box for each list item
        cntCheck    = uix.Grid( 'Parent', parent, 'Spacing', 2*AnimalDatabase.GUI_BORDER, 'Padding', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        if isempty(value)
          value     = obj.suggestedForFormat(format, data);
        end
        isValid     = [value{:,1}] ~= YesNoMaybe.default;
        template.data = AnimalDatabase.SPECS_YESNO;

        % First column is all the checkboxes
        for iCheck = 1:size(value,1)
          uicontrol ( 'Parent'              , cntCheck                                ...
                    , 'Style'               , 'pushbutton'                            ...
                    , 'String'              , ['<html>' YesNoMaybe.html(value{iCheck,1}) '</html>']         ...
                    , 'FontSize'            , AnimalDatabase.GUI_FONT                 ...
                    , 'BackgroundColor'     , YesNoMaybe.background(value{iCheck,1})  ...
                    , 'UserData'            , {state, template, value{iCheck,1}, value(iCheck,:)}           ...
                    , 'Interruptible'       , 'off'                                   ...
                    , 'BusyAction'          , 'cancel'                                ...
                    , 'TooltipString'       , '<html><div style="font-size:14px">Left- (right-)click to cycle forward (backward)</div></html>'  ...
                    );
        end
        
        % Second column is the list of items to be checked
        ctrl        = gobjects(1,size(value,1));
        for iCheck = 1:size(value,1)
          ctrl(iCheck)                                                                          ...
                    = uicontrol ( 'Parent'              , cntCheck                              ...
                                , 'Style'               , 'text'                                ...
                                , 'String'              , value{iCheck,2}                       ...
                                , 'HorizontalAlignment' , 'left'                                ...
                                , 'Interruptible'       , 'off'                                 ...
                                , 'BusyAction'          , 'cancel'                              ...
                                );
        end
        
        % Format layout
        if ~isempty(ctrl)
          set(cntCheck, 'Heights', -ones(1,size(value,1)), 'Widths', [AnimalDatabase.GUI_BTNSIZE,-1]);
        end
        height      = height * max(1,size(value,1));
        template.data = AnimalDatabase.SPECS_STRINGS;
                            
      elseif format{2}(1) == '?'
        %% Enumerated types are selected from a drop-down menu
        enumDefault = eval([format{2}(2:end) '.default']);
        if isempty(value)
          value     = enumDefault;
        end
        if state == EntryState.Unknown
          isValid   = value ~= enumDefault;
        end
        
        allValues   = arrayfun(@char, enumeration(format{2}(2:end)), 'UniformOutput', false);
        ctrl        = uicontrol ( 'Parent'              , parent                              ...
                                , 'Style'               , 'popupmenu'                         ...
                                , 'String'              , allValues                           ...
                                , 'Interruptible'       , 'off'                               ...
                                , 'BusyAction'          , 'cancel'                            ...
                                );
        if ~isempty(multiFormat)
          set(ctrl, 'Min', 0, 'Max', 2);
        end
        set(ctrl, 'Value', find(strcmp(allValues, arrayfun(@char,value,'UniformOutput',false))));
                            
      elseif format{2}(1) == '#'
        %% Per-day array of numerated types 
        if ~isempty(multiFormat)
          error('AnimalDatabase:guiForFormat', 'Array data not supported for per-day data.');
        end
        
        enumDefault = eval([format{2}(2:end) '.default']);
        if isempty(value)
          value     = repmat(enumDefault, size(AnimalDatabase.DAYS_OF_WEEK));
        end
        if state == EntryState.Unknown
          isValid   = value ~= enumDefault;
        else
          isValid   = repmat(isValid, size(AnimalDatabase.DAYS_OF_WEEK));
        end
        
        allValues   = arrayfun(@char, enumeration(format{2}(2:end)), 'UniformOutput', false);
        iToday      = weekday(now());
        cntCtrl     = uix.Grid( 'Parent', parent, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        ctrl        = gobjects(0);
        
        for iDay = 1:numel(AnimalDatabase.DAYS_OF_WEEK)
          if iDay == iToday
            fmt     = {'ForegroundColor', AnimalDatabase.CLR_SELECT, 'FontWeight', 'bold'};
          else
            fmt     = {'ForegroundColor', [0 0 0], 'FontWeight', 'normal'};
          end
                        uicontrol ( 'Parent'              , cntCtrl                               ...
                                  , 'Style'               , 'text'                                ...
                                  , 'String'              , AnimalDatabase.DAYS_OF_WEEK{iDay}     ...
                                  , 'FontSize'            , AnimalDatabase.GUI_FONT               ...
                                  , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG            ...
                                  , 'TooltipString'       , ['<html><div style="font-size:14px">' template.description '</div></html>'] ...
                                  , fmt{:}                                                        ...
                                  , 'Interruptible'       , 'off'                                 ...
                                  , 'BusyAction'          , 'cancel'                              ...
                                  );
          ctrl(end+1) = uicontrol ( 'Parent'              , cntCtrl                               ...
                                  , 'Style'               , 'popupmenu'                           ...
                                  , 'String'              , allValues                             ...
                                  , 'Value'               , find(strcmp(char(value(iDay)),allValues))   ...
                                  , fmt{:}                                                        ...
                                  , 'Interruptible'       , 'off'                                 ...
                                  , 'BusyAction'          , 'cancel'                              ...
                                  );
        end
        set(cntCtrl, 'Heights', [-1 -1.2], 'Widths', -ones(1,numel(AnimalDatabase.DAYS_OF_WEEK)));
        height      = height * 1.6;
        
      elseif format{2}(1) == '*'
        %% Line-by-line display of strings with an prespecified addition option
        cntCtrl     = uix.HBox( 'Parent', parent, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        if isempty(multiFormat)
          ctrl      = uicontrol ( 'Parent'              , cntCtrl                           ...
                                , 'Style'               , 'edit'                            ...
                                , 'String'              , value                             ...
                                , 'HorizontalAlignment' , 'left'                            ...
                                , 'Interruptible'       , 'off'                             ...
                                , 'BusyAction'          , 'cancel'                          ...
                                );
          support(end+1)                                                                    ...
                    = uicontrol ( 'Parent'              , cntCtrl                           ...
                                , 'Style'               , 'pushbutton'                      ...
                                , 'String'              , '...'                             ...
                                , 'TooltipString'       , ['<html><div style="font-size:14px">Add ' lower(template.description) '</div></html>']  ...
                                , 'FontSize'            , AnimalDatabase.GUI_FONT + 2       ...
                                , 'UserData'            , ctrl                              ...
                                , 'Callback'            , {@AnimalDatabase.setFromList, template.field, template.description, {obj.(['tmpl' format{2}(2:end)]).value}, ctrl}  ...
                                , 'Interruptible'       , 'off'                             ...
                                , 'BusyAction'          , 'cancel'                          ...
                                );
          set(cntCtrl, 'Widths', [-1, AnimalDatabase.GUI_BTNSIZE]);
        else
          ctrl      = uicontrol ( 'Parent'              , cntCtrl                           ...
                                , 'Style'               , 'listbox'                         ...
                                , 'String'              , value                             ...
                                , 'HorizontalAlignment' , 'left'                            ...
                                , 'Interruptible'       , 'off'                             ...
                                , 'BusyAction'          , 'cancel'                          ...
                                );
          support(end+1)                                                                    ...
                    = uicontrol ( 'Parent'              , cntCtrl                           ...
                                , 'Style'               , 'pushbutton'                      ...
                                , 'String'              , '+'                               ...
                                , 'TooltipString'       , ['<html><div style="font-size:14px">Add ' lower(template.description) '</div></html>']  ...
                                , 'FontSize'            , AnimalDatabase.GUI_FONT + 2       ...
                                , 'UserData'            , ctrl                              ...
                                , 'Callback'            , {@AnimalDatabase.addFromList, template.field, template.description, {obj.(['tmpl' format{2}(2:end)]).value}, ctrl}  ...
                                , 'Interruptible'       , 'off'                             ...
                                , 'BusyAction'          , 'cancel'                          ...
                                );
          support(end+1)                                                                    ...
                    = uicontrol ( 'Parent'              , cntCtrl                           ...
                                , 'Style'               , 'pushbutton'                      ...
                                , 'String'              , '-'                               ...
                                , 'TooltipString'       , ['<html><div style="font-size:14px">Remove currently selected ' template.field '</div></html>']  ...
                                , 'FontSize'            , AnimalDatabase.GUI_FONT + 2       ...
                                , 'UserData'            , ctrl                              ...
                                , 'Callback'            , {@AnimalDatabase.removeListEntry, ctrl}  ...
                                , 'Interruptible'       , 'off'                             ...
                                , 'BusyAction'          , 'cancel'                          ...
                                );
          height    = height * 1.5;
          set(cntCtrl, 'Widths', [-1, AnimalDatabase.GUI_BTNSIZE, AnimalDatabase.GUI_BTNSIZE]);
        end
        
      else
        %% All other formats use a text edit box, possibly multiline
        if isempty(multiFormat)
          value     = obj.applyFormat(value, format);
        else
          value     = obj.applyFormat(value, template.data);
        end
        if state == EntryState.Unknown
          isValid   = ~isempty(value);
        end
        
        ctrl        = uicontrol ( 'Parent'              , parent                            ...
                                , 'Style'               , 'edit'                            ...
                                , 'String'              , value                             ...
                                , 'HorizontalAlignment' , 'left'                            ...
                                , 'Interruptible'       , 'off'                             ...
                                , 'BusyAction'          , 'cancel'                          ...
                                );
        if ~isempty(multiFormat)
          set(ctrl, 'Min', 0, 'Max', 2);
          height    = height * 1.5;
        end
      end

      %% Common formatting and user data
      if isempty(ctrl)
        state       = [];
      elseif numel(ctrl) > 1
        state       = repmat(state, size(ctrl));
      end
      sel           = state == EntryState.Unknown;
      state(sel)    = EntryState(isValid(sel));
      
      for iCtrl = 1:numel(ctrl)
        %% Disallow editing of display-only quantities
        if state(iCtrl) == EntryState.DisplayOnly
          enable    = 'inactive';
        else
          enable    = 'on';
        end
        bkgColor    = EntryState.color(state(iCtrl));
        if strcmpi(get(ctrl(iCtrl),'Style'), 'text') && all(bkgColor == 1)
          bkgColor  = AnimalDatabase.CLR_GUI_BKG;
        end
        
        %% Set control properties
        set ( ctrl(iCtrl)                                               ...
            , 'Enable'              , enable                            ...
            , 'BackgroundColor'     , bkgColor                          ...
            , 'FontSize'            , AnimalDatabase.GUI_FONT         ...
            , 'TooltipString'       , ['<html><div style="font-size:14px">' template.description '</div></html>']   ...
            , 'UserData'            , {state(iCtrl), template, AnimalDatabase.getUIString(ctrl(iCtrl)), origValue}  ...
            );
      end
      
    end
    
    %----- Use the predefined format to construct a GUI table; evalData is used for computed quantities
    function [ctrlHandle, ctrlState, ctrlSupport, tableHeight] = populateTable(obj, hTable, data, template, isOwner, evalData, origData, headerWidth)
      if nargin < 8 || isempty(headerWidth)
        headerWidth       = AnimalDatabase.GUI_HEADER;
      end
      ctrHeight           = get(hTable, 'Heights');
      origRows            = numel(ctrHeight);
      
      %% Parse grouping information to decide what columns to display
      grouping            = [template.grouping];
      [index,grouping]    = SplitVec(grouping, 'equal', 'index', 'firstval');
      
      %% Add all data headers (first column)
      for iGrp = 1:numel(index)
        if grouping(iGrp) == 'X'
          continue;
        end
        if numel(index{iGrp}) > AnimalDatabase.MAX_ENTRIES_PER_ROW
          label           = '';
          desc            = '';
          id              = '';
        else
          label           = [template(index{iGrp}(1)).field, ' :'];
          desc            = template(index{iGrp}(1)).description;
          id              = template(index{iGrp}(1)).identifier;
        end
        uicontrol ( 'Parent'              , hTable                                ...
                  , 'Style'               , 'text'                                ...
                  , 'String'              , label                                 ...
                  , 'TooltipString'       , ['<html><div style="font-size:14px">' desc '</div></html>'] ...
                  , 'FontSize'            , AnimalDatabase.GUI_FONT               ...
                  , 'HorizontalAlignment' , 'right'                               ...
                  , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG            ...
                  , 'UserData'            , id                                    ...
                  , 'Interruptible'       , 'off'                                 ...
                  , 'BusyAction'          , 'cancel'                              ...
                  );
      end
      
      %% Add all data entry controls (second column)
      ctrlHandle          = {};
      ctrlState           = {};
      ctrlSupport         = {};
      for iGrp = 1:numel(index)
        if grouping(iGrp) == 'X'
          continue;
        end
        
        if numel(index{iGrp}) > AnimalDatabase.MAX_ENTRIES_PER_ROW
          %% Multiple entries in a column-wise grid
          cntCtrl         = uix.Grid( 'Parent', hTable, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
          height          = nan(size(index{iGrp}));
          for iSub = 1:numel(index{iGrp})
            tmpl          = template(index{iGrp}(iSub));
            
            uicontrol ( 'Parent'              , cntCtrl                           ...
                      , 'Style'               , 'text'                            ...
                      , 'String'              , [tmpl.field ' :']                 ...
                      , 'TooltipString'       , ['<html><div style="font-size:14px">' tmpl.description '</div></html>'] ...
                      , 'FontSize'            , AnimalDatabase.GUI_FONT           ...
                      , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG        ...
                      , 'UserData'            , tmpl.identifier                   ...
                      , 'Interruptible'       , 'off'                             ...
                      , 'BusyAction'          , 'cancel'                          ...
                      );
            [ctrlHandle{end+1}, ctrlState{end+1}, height(iSub), ctrlSupport{end+1}]       ...
                          = obj.guiForFormat( cntCtrl, tmpl, data.(tmpl.identifier), evalData, origData.(tmpl.identifier), isOwner );
          end
          ctrHeight(end+1)= max(height) + 0.8*AnimalDatabase.GUI_BTNSIZE;
          fieldWidth      = cellfun(@(x) 2*sum(isstrprop(x,'upper')) + sum(isstrprop(x,'lower')), {template(index{iGrp}).field});
          set(cntCtrl, 'Heights', [-1,max(height)], 'Widths', -fieldWidth);
          
        elseif numel(index{iGrp}) > 1
          %% Multiple entries in a single row
          cntCtrl         = uix.HBox( 'Parent', hTable, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
          height          = nan(size(index{iGrp}));
          for iSub = 1:numel(index{iGrp})
            tmpl          = template(index{iGrp}(iSub));
            if iSub > 1
              uicontrol ( 'Parent'              , cntCtrl                           ...
                        , 'Style'               , 'text'                            ...
                        , 'String'              , [tmpl.field ' :']                 ...
                        , 'TooltipString'       , ['<html><div style="font-size:14px">' tmpl.description '</div></html>'] ...
                        , 'FontSize'            , AnimalDatabase.GUI_FONT           ...
                        , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG        ...
                        , 'HorizontalAlignment' , 'right'                           ...
                        , 'UserData'            , tmpl.identifier                   ...
                        , 'Interruptible'       , 'off'                             ...
                        , 'BusyAction'          , 'cancel'                          ...
                        );
            end
            [ctrlHandle{end+1}, ctrlState{end+1}, height(iSub), ctrlSupport{end+1}]       ...
                          = obj.guiForFormat( cntCtrl, tmpl, data.(tmpl.identifier), evalData, origData.(tmpl.identifier), isOwner );
          end
          ctrHeight(end+1)= max(height);
          
        else
          %% Individual entry
          tmpl            = template(index{iGrp});
          [ctrlHandle{end+1}, ctrlState{end+1}, ctrHeight(end+1), ctrlSupport{end+1}]     ...
                          = obj.guiForFormat( hTable, tmpl, data.(tmpl.identifier), evalData, origData.(tmpl.identifier), isOwner );
        end
      end
      
      %% Format layout
      AnimalDatabase.mergeTabularGrid(hTable, origRows);
      tableHeight         = sum(ctrHeight) + numel(ctrHeight)*AnimalDatabase.GUI_BORDER;
      set(hTable, 'Heights', ctrHeight, 'Widths', [headerWidth, -1]);
      set(get(hTable,'Parent'), 'MinimumHeight', tableHeight);
    end
    
    %----- Retrieve data from a given set of controls, the latter as created by populateTable()
    function [data, isValid, origData] = getTableData(obj, ctrl, value)
      %% Default arguments
      if nargin < 3
        value           = [];
      elseif ~isempty(value) &&  ~iscell(value)
        value           = {value};
      end
      
      %% Loop through controls to check
      data              = struct();
      origData          = struct();
      isValid           = false(size(ctrl));
      for iCtrl = 1:numel(ctrl)
        %% Get how this data is specified
        info            = get(ctrl(iCtrl), 'UserData');
        tmpl            = info{2};
        if isfield(tmpl,'isDynamic') && strcmpi(tmpl.isDynamic,'yes')
          continue;     % this data is dynamically updated from external sources
        end
        
        format          = tmpl.data;
        origData.(tmpl.identifier)      = info{4};

        %% Special case of array data -- assume that we're reading a single entry right now
        multiFormat     = regexp(format{2}, AnimalDatabase.RGX_MULTI_FORMAT, 'tokens' ,'once');
        if isempty(multiFormat)
          isArray       = false;
        else
          isArray       = true;
%           format{2}     = multiFormat{:};
        end
        
        %% Special case of week-based daily entries -- convert to single entries
        if isempty(strfind(format{2}, '#'))
          isDaily       = false;
        else
          isDaily       = true;
          format{2}     = strrep(format{2}, '#', '?');
        end
        
        %% Get and convert the entered value to the target format
        if isempty(value)
          input         = AnimalDatabase.getUIString(ctrl(iCtrl));
        else
          input         = value{iCtrl};
        end
        
        [parsed, isValid(iCtrl)]          ...
                        = obj.parseAsFormat(input, format, isfield(tmpl,'mandatory') && strcmpi(tmpl.mandatory,'yes'));
        
        %% Allow concatenation of multi-entry fields
        if ~isfield(data, tmpl.identifier)
          data.(tmpl.identifier) = parsed;
        elseif ~isArray && ~isDaily
          error('AnimalDatabase:getTableData', 'Repeated identifier "%s" found for non-multiple data.', tmpl.identifier);
        elseif ~isArray || ~isDaily
          data.(tmpl.identifier)        = [data.(tmpl.identifier), parsed];
        elseif numel(data.(tmpl.identifier){end}) < numel(AnimalDatabase.DAYS_OF_WEEK)
          data.(tmpl.identifier){end}   = [data.(tmpl.identifier){end}, parsed{:}];
        else
          data.(tmpl.identifier){end+1} = parsed{:};
        end
      end
    end
    
    %----- Validate a particular data entry and decide whether to enable/disable committing 
    function validateData(obj, hObject, event, index, hCommit, keypressHack, hDate)
      %% This is some incredibly ugly HACK to ensure that the editbox String is populated
      % https://www.mathworks.com/matlabcentral/answers/26036-how-to-update-editbox-uicontrol-string-during-keypressfcn
      if keypressHack
        robot         = java.awt.Robot;
        uicontrol(hObject);
        robot.keyPress(java.awt.event.KeyEvent.VK_ENTER);
        pause(0.001);
        uicontrol(hObject);
        robot.keyRelease(java.awt.event.KeyEvent.VK_ENTER);
        pause(0.001);
      end
      
      %% Only take action if the value has changed from previously
      value           = AnimalDatabase.getUIString(hObject);
      state           = get(hObject, 'UserData');
      if isequaln(value, state{3})
        return;
      end
      state{3}        = value;
      set(hObject, 'UserData', state);

      %% Check for validity, with cage ID as a special case to impose animal quotas
      [data, isValid] = obj.getTableData(hObject, value);
      if isfield(data,'cage') && ~strcmpi(data.cage, state{4})
        hGroup        = obj.cnt.groupAni( strcmpi(get(obj.cnt.groupAni,'UserData'), data.cage) );
        hAni          = get(hGroup, 'Children');
        if      isempty(data.cage)                              ...
            ||  ( ~isempty(hGroup)                              ...
               && numel(hAni) > AnimalDatabase.MAX_ANI_GROUP    ...
                )
          isValid     = false;
        end
      end
      
      %% If data is valid (or not), color the background appropriately
      if isValid
        set(hObject, 'BackgroundColor', [1 1 1]);
      else
        set(hObject, 'BackgroundColor', EntryState.color(EntryState.Invalid));
      end
      
      %% If all checked data is valid, enable the commit button
      info            = get(hCommit, 'UserData');
      info{1}(index)  = isValid;
      if all(info{1})
        enable        = 'on';
      else
        enable        = 'off';
      end
      set(hCommit, 'UserData', info, 'Enable', enable);
      
      %% If a date control is provided, update the modification effective time
      if ~isempty(hDate)
        status        = get(hDate, 'UserData');
        if any(status{5} == AnimalDatabase.EMERGENCY_STATUS)
          % This is because status redactions must take effect today, but also makes it so that
          % editing the detailed handling plan of missing/dead animals has an earlier effective date
          % than for live animals. Since I don't know what it means for you to design a plan for a
          % missing/dead animal anyway, I'm just going to leave it like this.
          effective   = datevec(now());
        else
          effective   = obj.changeEffectiveDate();
        end
        set(hDate, 'String', obj.applyFormat(effective, AnimalDatabase.SPECS_DATE), 'BackgroundColor', get(obj.btn.responsible, 'BackgroundColor'));
      end
    end
    
    %----- Validate a particular data entry and decide whether to enable/disable committing
    function validateCheckbox(obj, hObject, event, index, hLabel, hCommit, direction)
      %% Cycle through available states
      info            = get(hObject, 'UserData');
      value           = YesNoMaybe.cycle(info{3}, direction);
      info{3}         = value;
      set(hObject, 'String', ['<html>' YesNoMaybe.html(value) '</html>'], 'BackgroundColor', YesNoMaybe.background(value), 'UserData', info);

      %% If data is valid, color the background appropriately
      [data, isValid] = obj.getTableData(hObject, value);
      if isValid
        set(hLabel, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG);
      else
        set(hLabel, 'BackgroundColor', EntryState.color(EntryState.Invalid));
      end
      
      %% If all checked data is valid, enable the commit button
      info            = get(hCommit, 'UserData');
      info{1}(index)  = isValid;
      if all(info{1})
        enable        = 'on';
      else
        enable        = 'off';
      end
      set(hCommit, 'UserData', info, 'Enable', enable);
    end

    
    %----- (Re-)create GUI figure and layout for animal info display
    function layoutGUI(obj)

      %% Create figure to populate
      obj.closeGUI();
      obj.figGUI              = makePositionedFigure( AnimalDatabase.GUI_POSITION                     ...
                                                    , AnimalDatabase.GUI_MONITOR                      ...
                                                    , 'OuterPosition'                                 ...
                                                    , 'Name'            , [AnimalDatabase.GUI_TITLE ' Database']  ...
                                                    , 'ToolBar'         , 'none'                      ...
                                                    , 'MenuBar'         , 'none'                      ...
                                                    , 'NumberTitle'     , 'off'                       ...
                                                    , 'Visible'         , 'off'                       ...
                                                    , 'Tag'             , 'persist'                   ...
                                                    , 'CloseRequestFcn' , @obj.closeGUI               ...
                                                    );
      
      %% Define main controls and data display regions
      obj.cnt.main            = uix.VBox( 'Parent', obj.figGUI, 'Spacing', 5*AnimalDatabase.GUI_BORDER, 'Padding', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.config          = uix.HBox( 'Parent', obj.cnt.main, 'Spacing', AnimalDatabase.GUI_BORDER, 'Padding', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.data            = uix.HBoxFlex( 'Parent', obj.cnt.main, 'Spacing', 3*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      % Top bar: selector for responsible, action buttons
      obj.cnt.person          = uix.HBox( 'Parent', obj.cnt.config, 'Spacing', 2*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.controls        = uix.HBox( 'Parent', obj.cnt.config, 'Spacing', 2*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      % Responsible selector
      obj.btn.responsible     = uicontrol( 'Parent', obj.cnt.person, 'Style', 'pushbutton', 'String', 'Responsible'                                                 ...
                                         , 'TooltipString', '<html><div style="font-size:14px">View/edit person info</div></html>'                                  ...
                                         , 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      obj.lst.responsible     = uicontrol( 'Parent', obj.cnt.person, 'Style', 'popupmenu', 'String', {'( select yourself )'}, 'FontSize', AnimalDatabase.GUI_FONT   ...
                                         , 'Callback', @obj.showResponsible, 'Interruptible', 'off', 'BusyAction', 'queue' );
      
      % Things to do
                                uix.Empty( 'Parent', obj.cnt.controls );
      obj.axs.scaleRead       = axes( 'Parent', obj.cnt.controls, 'XLim', [1 100], 'YLim', [0 50], 'Box', 'on', 'ActivePositionProperty', 'Position'                ...
                                    , 'XColor', [1 1 1]*0.7, 'YColor', [1 1 1]*0.7, 'XTick', [], 'YTick', [], 'Visible', 'off', 'Clipping', 'off' );
      obj.btn.weighMode       = uicontrol( 'Parent', obj.cnt.controls, 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel', 'UserData', 0 );
                                uix.Empty( 'Parent', obj.cnt.controls );
      obj.btn.checkInOut      = uicontrol( 'Parent', obj.cnt.controls, 'Style', 'pushbutton', 'String', 'Check In/Out'                                              ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Selection screen to check in/out cages</div></html>'                 ...
                                         , 'FontSize', AnimalDatabase.GUI_FONT, 'Enable', 'off', 'Interruptible', 'off', 'BusyAction', 'cancel' );
      obj.btn.finalize        = uicontrol( 'Parent', obj.cnt.controls, 'Style', 'pushbutton', 'String', 'FINALIZE'                                                  ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Check that all animals you''re responsible for have been handled</div></html>'                       ...
                                         , 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      obj.setScaleState();

      %% Define live data display
      obj.cnt.overview        = uix.VBox( 'Parent', obj.cnt.data, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.details         = uix.VBoxFlex( 'Parent', obj.cnt.data, 'Spacing', 3*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      obj.cnt.researcher      = uix.HButtonBox( 'Parent', obj.cnt.overview, 'Spacing', AnimalDatabase.GUI_BORDER, 'ButtonSize', [5 2]*AnimalDatabase.GUI_BTNSIZE, 'HorizontalAlignment', 'left', 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.groupScroll     = uix.ScrollingPanel( 'Parent', obj.cnt.overview );
      obj.cnt.aniGroups       = uix.VBox( 'Parent', obj.cnt.groupScroll, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      %% Define animal details display
      obj.cnt.aniInfo         = uix.HBox( 'Parent', obj.cnt.details, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.dailyScroll     = uix.ScrollingPanel( 'Parent', obj.cnt.details );
      obj.tbl.aniDaily        = uix.Grid( 'Parent', obj.cnt.dailyScroll, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );

      cntAni                  = uix.VBox( 'Parent', obj.cnt.aniInfo, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.tbl.aniID           = uix.Grid( 'Parent', cntAni, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.axs.aniImage        = Canvas( AnimalDatabase.ANI_IMAGE_SIZE, cntAni, true, [1 1 1], 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.dataScroll      = uix.ScrollingPanel( 'Parent', obj.cnt.aniInfo );
      obj.tbl.aniData         = uix.Grid( 'Parent', obj.cnt.dataScroll, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );

      
      %% Configure layout proportions
      elemSize                = AnimalDatabase.GUI_BTNSIZE + AnimalDatabase.GUI_BORDER;
      aniIDHeight             = (1 + numel(AnimalDatabase.ANI_ID_INFO)) * elemSize;
      
      set(obj.cnt.main      , 'Heights', [1.2*AnimalDatabase.GUI_BTNSIZE + 2*AnimalDatabase.GUI_BORDER, -1]);
      set(obj.cnt.config    , 'Widths' , [10*AnimalDatabase.GUI_BTNSIZE, -1]);
      set(obj.cnt.person    , 'Widths' , [4*AnimalDatabase.GUI_BTNSIZE, -1]);
      set(obj.cnt.controls  , 'Widths' , [AnimalDatabase.GUI_BTNSIZE, -1, 7*AnimalDatabase.GUI_BTNSIZE, AnimalDatabase.GUI_BTNSIZE, 4*AnimalDatabase.GUI_BTNSIZE, 9.5*AnimalDatabase.GUI_BTNSIZE]);
      set(obj.cnt.data      , 'Widths' , [3*(1 + AnimalDatabase.MAX_ANI_GROUP)*elemSize + 0.5*AnimalDatabase.GUI_BTNSIZE, -1]);
      set(obj.cnt.overview  , 'Heights', [2*AnimalDatabase.GUI_BTNSIZE, -1]);

      set(cntAni            , 'Heights', [aniIDHeight, -1]);
      set(obj.cnt.details   , 'Heights', [5*AnimalDatabase.ANI_IMAGE_SIZE(1) + aniIDHeight, -1]);
      set(obj.cnt.aniInfo   , 'Widths' , [5*AnimalDatabase.ANI_IMAGE_SIZE(1) + Canvas.GUI_BTNSIZE, -1]);
      
    end
    
    %----- Load the list of responsibles into the GUI
    function layoutResponsibles(obj, personID)
      %% Default arguments
      if nargin < 2
        personID  = [];
      end
      
      %% Populate responsibles list
      obj.pullOverview();
      set ( obj.lst.responsible                                                     ...
          , 'String'        , {obj.Technicians.ID, obj.Researchers.ID}              ...
          );
        
      %% Select a particular responsible, if provided
      if ~isempty(personID)
        index  = find(strcmpi(get(obj.lst.responsible, 'String'), personID));
        if isempty(index)
          error('AnimalDatabase:layoutResponsibles', 'Person %s not found in the list of technicians/researchers.', personID);
        end
        set( obj.lst.responsible, 'Value', index );
      end
        
      obj.showResponsible([], [], false);
    end
    
    %----- Setup a timer for live updates of RightNow status
    function setupUpdateTimer(obj)
      %% Recreate timer object
      if ~isempty(obj.tmrRightNow) && isvalid(obj.tmrRightNow)
        stop(obj.tmrRightNow);
      end
      obj.tmrRightNow     = timer ( 'Name'                    , ['rightNow-' obj.whoAmI]            ...
                                  , 'BusyMode'                , 'drop'                              ...
                                  , 'ExecutionMode'           , 'fixedSpacing'                      ...
                                  , 'Period'                  , AnimalDatabase.UPDATE_PERIOD        ...
                                  , 'TimerFcn'                , @obj.updateAnimalSummary            ...
                                  , 'StopFcn'                 , @obj.stopUpdateTimer                ...
                                  );
      start(obj.tmrRightNow);
    end

    
    %----- Recreate the GUI display according to the currently selected responsible
    function showResponsible(obj, hObject, event, showNextAni)
      if nargin < 4 || isempty(showNextAni)
        showNextAni         = true;
      end
      
      %% Set busy cursor
      allPeople             = get( obj.lst.responsible, 'String' );
      if isempty(allPeople)
        return;
      end
      alreadyBusy           = obj.waitImWorking();

      %% Show the type of responsible
      personID              = allPeople{get( obj.lst.responsible, 'Value' )};
      if any(strcmpi({obj.Technicians.ID}, personID))
        isATech             = true;
        set( obj.btn.responsible, 'String', 'Technician', 'BackgroundColor', AnimalDatabase.CLR_TECHNICIAN, 'UserData', personID );
      else
        isATech             = false;
        set( obj.btn.responsible, 'String', 'Researcher', 'BackgroundColor', AnimalDatabase.CLR_RESEARCHER, 'UserData', personID );
      end
      
      %% Create buttons for each researcher in the responsibility list of the current person
      [primary,secondary]   = obj.whatShouldIDo(personID);
      responsibility        = {primary, secondary};
      
      delete(get(obj.cnt.researcher, 'Children'));
      delete(get(obj.cnt.aniGroups , 'Children'));
      
      cntAdd                = uix.VBox('Parent', obj.cnt.researcher, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG);
      uicontrol ( 'Parent', cntAdd, 'Style', 'text', 'String', 'Owner:', 'FontSize', AnimalDatabase.GUI_FONT, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG   ...
                , 'HorizontalAlignment', 'right', 'Interruptible', 'off', 'BusyAction', 'cancel' );
      obj.btn.addGroup      = uicontrol ( 'Parent'            , cntAdd                                          ...
                                        , 'Style'             , 'pushbutton'                                    ...
                                        , 'String'            , 'Add cage'                                      ...
                                        , 'FontSize'          , AnimalDatabase.GUI_FONT                         ...
                                        , 'BackgroundColor'   , AnimalDatabase.CLR_ADD_BTN                      ...
                                        , 'Callback'          , @obj.addAnimalGroup                             ...
                                        , 'Interruptible'     , 'off'                                           ...
                                        , 'BusyAction'        , 'cancel'                                        ...
                                        );
      
      obj.btn.showWhose     = gobjects(0);
      for iRes = 1:numel(responsibility)
        if ~isempty(obj.btn.showWhose) && ~isempty(responsibility{iRes})
          uix.Empty('Parent', obj.cnt.researcher);
        end
        for iID = 1:numel(responsibility{iRes})
          obj.btn.showWhose(end+1)                                                                              ...
                            = uicontrol ( 'Parent'            , obj.cnt.researcher                              ...
                                        , 'Style'             , 'togglebutton'                                  ...
                                        , 'String'            , responsibility{iRes}(iID).ID                    ...
                                        , 'TooltipString'     , ['<html><div style="font-size:14px">' responsibility{iRes}(iID).Name '</div></html>'] ...
                                        , 'FontSize'          , AnimalDatabase.GUI_FONT                         ...
                                        , 'Callback'          , {@obj.showAnimalList, responsibility{iRes}(iID).ID} ...
                                        , 'UserData'          , responsibility{iRes}(iID).ID                    ...
                                        , 'Interruptible'     , 'off'                                           ...
                                        , 'BusyAction'        , 'cancel'                                        ...
                                        );
        end
      end
      
      %% Restore non-busy cursor
      set(obj.btn.checkInOut, 'Enable', 'on', 'Callback', {@obj.checkoutGUI, personID});
      set(obj.btn.finalize, 'Callback', {@obj.areWeThereYet, personID});

      obj.checkUpdateTimer([], [], true);
      if showNextAni
        if isATech
          obj.nextInLine(hObject, event);
        else
          obj.nextInLine(hObject, event, personID);
        end
      end
      obj.okImDone(alreadyBusy);
    end
    
    %----- Recreate the GUI display for the currently loaded list of animals
    function showAnimalList(obj, hObject, event, researcherID, showNextAni)
      if nargin < 5 || isempty(showNextAni)
        showNextAni           = false;
      end
      
      %% Enforce only one list at once
      alreadyBusy             = obj.waitImWorking();
      set(obj.btn.showWhose , 'Value', 0, 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED);
      set(hObject           , 'Value', 1, 'BackgroundColor', get(obj.btn.responsible, 'BackgroundColor'));

      %% Fetch animal list from database
      isOwner                 = strcmpi(researcherID, get(obj.btn.responsible, 'UserData'));
      animal                  = obj.whatIsThePlan(obj.pullAnimalList(researcherID), isOwner);
      decommissioned          = [animal.status] >= HandlingStatus.AdLibWater;
      remaining               = animal(decommissioned);
      animal                  = animal(~decommissioned);
      [grpName,grpIndex]      = AnimalDatabase.getCages(animal);
      
      %% Create an animal group per cage
      delete(get(obj.cnt.aniGroups, 'Children'));
      
      set(obj.cnt.aniGroups, 'UserData', researcherID);
      set(obj.cnt.groupScroll, 'MinimumHeights', AnimalDatabase.GUI_BORDER);
      
      obj.pnl.aniGroup        = gobjects(0);
      obj.cnt.groupAni        = gobjects(0);
      obj.btn.aniInfo         = gobjects(0);
      obj.btn.aniAdd          = gobjects(0);
      
      for iGrp = 1:numel(grpName)
        %% Add a panel grouping animals by cage
        grpAni                = animal(grpIndex == iGrp);
        [cntGroup, btnAdd]    = obj.addAnimalGroup([], [], grpName{iGrp});
        for iAni = 1:numel(grpAni)
          obj.addAnimal(btnAdd, [], cntGroup, grpAni(iAni).ID, grpAni(iAni).status, grpAni(iAni).imageFile);
        end
      end
      
      %% Add remaining animals as a decommissioned group
      if ~isempty(remaining)
        obj.addDecommGroup(remaining);
      end
      
      %% Restore non-busy cursor
      obj.checkUpdateTimer([], [], true);
      if showNextAni
        obj.nextInLine(hObject, event, researcherID);
      end
      obj.okImDone(alreadyBusy);
    end

    %----- Recreate the GUI display for details of the currently loaded animal
    function showAnimalDetails(obj, hObject, event, researcherID, animalID, animal, isNewAni)
      if nargin < 6
        animal            = [];
      end
      if nargin < 7
        isNewAni          = false;
      end

      %% Set busy pointer
      ctrlID              = {};
      idState             = {};
      ctrlSupport         = {};
      alreadyBusy         = obj.waitImWorking();
      
      %% Enforce only one animal detail at once
      set(obj.btn.aniInfo, 'Value', 0);
      set(hObject        , 'Value', 1);
      hPanel              = findParent(hObject, 'uipanel');
      set(obj.pnl.aniGroup, 'HighlightColor', [1 1 1]                                   , 'ShadowColor', [1 1 1]*0.7, 'BorderWidth', 1);
      set(hPanel          , 'HighlightColor', get(obj.btn.responsible,'BackgroundColor'), 'ShadowColor', [1 1 1]*0.5, 'BorderWidth', 4);
      set(obj.btn.weighMode, 'UserData', 0);
      
      %% Obtain logs for today; can be overridden by providing e.g. a new animal info struct
      when                = datevec(now());
      if isempty(animal)
        [logs,animal]     = obj.pullDailyLogs(researcherID, animalID);
      else
        logs              = [];
      end
      
      % Owner-specific plans are shown only in this details panel; leave the full animal struct as
      % it is for the purposes of showing daily logs w.r.t. the plan currently in effect
      isOwner             = strcmpi(researcherID, get(obj.btn.responsible, 'UserData'));
      inEffect            = obj.whatIsThePlan(animal, isOwner, isNewAni);
      
      %% Set animal-specific displays
      delete(get(obj.tbl.aniID  , 'Children'));
      delete(get(obj.tbl.aniData, 'Children'));
      
      if isempty(animal.image)
        animal.image      = 255*ones([AnimalDatabase.ANI_IMAGE_SIZE, 3], 'uint8');
      end
      obj.axs.aniImage.setImage(animal.image);
      obj.axs.aniImage.setCommitCallback({@obj.pushAnimalInfo, researcherID, animalID, 'image'});
      set(obj.axs.aniImage, 'Visible', 'on');
      
      %% Animal ID display
      % Special entry for cage name (although editable, inconsistencies with the GUI are the user's problem)
      template            = obj.tmplAnimal( strcmpi('cage', {obj.tmplAnimal.identifier}) );
      [ctrlID{end+1}, idState{end+1}, ~, ctrlSupport{end+1}]                                      ...
                          = obj.guiForFormat( obj.tbl.aniID, template, inEffect.(template.identifier), {inEffect}, inEffect.(template.identifier) );
      set(ctrlID{end}, 'HorizontalAlignment', 'center', 'FontSize', AnimalDatabase.GUI_FONT * 1.2, 'FontWeight', 'bold');

      % First column: headers
      template            = {};
      for idInfo = AnimalDatabase.ANI_ID_INFO
        template{end+1}   = obj.tmplAnimal( strcmpi(idInfo{:}, {obj.tmplAnimal.identifier}) );
        uicontrol( 'Parent', obj.tbl.aniID, 'Style', 'text', 'String', [template{end}.field ' :'], 'FontSize', AnimalDatabase.GUI_FONT  ...
                 , 'TooltipString', ['<html><div style="font-size:14px">' template{end}.description '</div></html>']                    ...
                 , 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG, 'HorizontalAlignment', 'right', 'Interruptible', 'off', 'BusyAction', 'cancel' );
      end
      
      % Second column: values
      obj.btn.editAni     = uicontrol ( 'Parent'              , obj.tbl.aniID                     ...
                                      , 'Style'               , 'pushbutton'                      ...
                                      , 'String'              , ['Edit ' animal.ID]               ...
                                      , 'FontSize'            , AnimalDatabase.GUI_FONT           ...
                                      , 'FontWeight'          , 'bold'                            ...
                                      , 'TooltipString'       , '<html><div style="font-size:14px">Edit/upload animal information</div></html>'   ...
                                      , 'Interruptible'       , 'off'                             ...
                                      , 'BusyAction'          , 'cancel'                          ...
                                      );
      for iTmpl = 1:numel(template)
        [ctrlID{end+1}, idState{end+1}, ~, ctrlSupport{end+1}]                                    ...
                        = obj.guiForFormat( obj.tbl.aniID, template{iTmpl}, inEffect.(template{iTmpl}.identifier), {inEffect}, inEffect.(template{iTmpl}.identifier) );
      end
      
      %% Allow modification of future plans only for the owner, also keep track of the handling status
      set(obj.tbl.aniID, 'Heights', -ones(1,1+numel(template)), 'Widths', [-1 -1]);

      if isOwner
        ctrlDate        = ctrlID{end};
        cutoffTime      = obj.applyFormat(obj.NotificationSettings.ChangeCutoffTime, AnimalDatabase.SPECS_TIME);
        tip             = get(ctrlDate, 'TooltipString');
        tip             = strrep(tip, '</div>', ['<br/><font color="red"><b>N.B. Handling plan changes past ' cutoffTime ' will only take effect the next day!</b></font></div>']);
        set(ctrlDate, 'UserData', [get(ctrlDate,'UserData'), {inEffect.status}], 'TooltipString', tip);
        set(AnimalDatabase.getSibling(ctrlDate), 'TooltipString', tip);
      else
        ctrlDate        = [];
      end
      
      
      %% Special case for status / tech duties for which only the owner sees full disclosure
      template            = obj.tmplAnimal;
      if ~isOwner
        sel               = ismember({template.identifier}, {'status','techDuties'});
        tmplActions       = template(sel);
        template(sel)     = [];
      end
      
      %% Parse information table according to pre-specified templates
      elemSize            = AnimalDatabase.GUI_BTNSIZE + AnimalDatabase.GUI_BORDER;
      [ctrlData, dataState, dataSupport, tableHeight]              ...
                          = obj.populateTable(obj.tbl.aniData, inEffect, template, isOwner, {inEffect}, inEffect, AnimalDatabase.GUI_HEADER);
                        
      % For some animals we only have logs up to a certain date
      if inEffect.status >= HandlingStatus.Missing
        when              = logs(end).date;
      end
      set(obj.tbl.aniDaily, 'UserData', {researcherID, animalID, when, ctrlData});
      
      
      %% Special case for status/duties for which non-owners sees an effective list and major status change options
      if ~isOwner
        %% Get original parameters for combination
        compHeights       = get(obj.tbl.aniData, 'Heights' );
        compWidths        = get(obj.tbl.aniData, 'Widths'  );
        children          = flipud(reshape(get(obj.tbl.aniData, 'Children'), [], 2));
        
        %% Headers for special actions
        for iTmpl = 1:numel(tmplActions)
          uicontrol( 'Parent', obj.tbl.aniData, 'Style', 'text', 'String', [tmplActions(iTmpl).field ' :'], 'FontSize', AnimalDatabase.GUI_FONT   ...
                   , 'TooltipString', ['<html><div style="font-size:14px">' tmplActions(iTmpl).description '</div></html>']                       ...
                   , 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG, 'HorizontalAlignment', 'right', 'Interruptible', 'off', 'BusyAction', 'cancel' );
        end
        
        %% Major status changes that cause the owner to be immediately notified
        obj.btn.statChange= gobjects(1, numel(AnimalDatabase.EMERGENCY_STATUS));
        cntStatChange     = uix.HButtonBox( 'Parent', obj.tbl.aniData, 'Spacing', AnimalDatabase.GUI_BTNSIZE, 'ButtonSize', [6 2]*AnimalDatabase.GUI_BTNSIZE, 'HorizontalAlignment', 'center', 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        for iStatus = 1:numel(AnimalDatabase.EMERGENCY_STATUS)
          status          = AnimalDatabase.EMERGENCY_STATUS(iStatus);
          obj.btn.statChange(iStatus)                                                             ...
                          = uicontrol ( 'Parent'              , cntStatChange                     ...
                                      , 'Style'               , 'pushbutton'                      ...
                                      , 'String'              , ['FLAG ' char(status)]            ...
                                      , 'FontSize'            , AnimalDatabase.GUI_FONT           ...
                                      , 'TooltipString'       , ['<html><div style="font-size:14px">Flag animal as ' char(status) ' and notify owner</div></html>']   ...
                                      , 'Callback'            , {@obj.majorStatusChange, researcherID, animalID, status, hObject}                                     ...
                                      , 'Interruptible'       , 'off'                             ...
                                      , 'BusyAction'          , 'cancel'                          ...
                                      );
          if inEffect.status == status
            set(obj.btn.statChange(iStatus), 'Enable', 'off');
          end
        end
        
        %% Simplified table of tech responsibilities for each day
        template          = tmplActions(2);
        iToday            = weekday(now());
        cntPlan           = uix.VBox( 'Parent', obj.tbl.aniData, 'Spacing', 1, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        cntDay            = uix.HBox( 'Parent', cntPlan, 'Spacing', AnimalDatabase.GUI_BORDER, 'Padding', 1, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
        for iDay = 1:numel(AnimalDatabase.DAYS_OF_WEEK)
          cfg             = { 'Parent', cntDay, 'Style', 'text', 'String', AnimalDatabase.DAYS_OF_WEEK{iDay}, 'FontSize', AnimalDatabase.GUI_FONT           ...
                            , 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG, 'HorizontalAlignment', 'center'                                                ...
                            , 'TooltipString', ['<html><div style="font-size:14px">' template.description '</div></html>']                                  ...
                            , 'Interruptible', 'off', 'BusyAction', 'cancel' };
          if iDay == iToday
            uicontrol(cfg{:}, 'ForegroundColor', AnimalDatabase.CLR_SELECT, 'FontWeight', 'bold');
          else
            uicontrol(cfg{:}, 'ForegroundColor', [1 1 1]*0.6, 'FontWeight', 'normal');
          end
        end
        
        if inEffect.status == HandlingStatus.InExperiments
          %% Only animals in experiments have detailed day-to-day instructions
          cntDuty         = uix.HBox( 'Parent', cntPlan, 'Spacing', AnimalDatabase.GUI_BORDER, 'Padding', 1, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
          for iDay = 1:numel(AnimalDatabase.DAYS_OF_WEEK)
            cfg           = { 'Parent', cntDuty, 'Style', 'text', 'String', char(inEffect.techDuties(iDay)), 'FontSize', AnimalDatabase.GUI_FONT                            ...
                            , 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG, 'TooltipString', ['<html><div style="font-size:14px">' template.description '</div></html>']   ...
                            , 'HorizontalAlignment', 'center', 'Interruptible', 'off', 'BusyAction', 'cancel' };
            if iDay == iToday
              uicontrol(cfg{:}, 'ForegroundColor', AnimalDatabase.CLR_SELECT, 'FontWeight', 'bold');
            else
              uicontrol(cfg{:}, 'ForegroundColor', [1 1 1]*0.6, 'FontWeight', 'normal');
            end
          end
        else
          %% Otherwise create a single display
          if inEffect.status == HandlingStatus.WaterRestrictionOnly
            techDuty      = Responsibility.Water;
          else
            techDuty      = Responsibility.Nothing;
          end
          uicontrol ( 'Parent', cntPlan, 'Style', 'text', 'String', ['~~~~~~  ' char(techDuty) '  ~~~~~~'], 'FontSize', AnimalDatabase.GUI_FONT                             ...
                    , 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG, 'TooltipString', ['<html><div style="font-size:14px">' template.description '</div></html>']           ...
                    , 'HorizontalAlignment', 'center', 'ForegroundColor', AnimalDatabase.CLR_SELECT, 'FontWeight', 'bold', 'Interruptible', 'off', 'BusyAction', 'cancel' );
        end
        
        %% Format layout
        AnimalDatabase.mergeTabularGrid(obj.tbl.aniData, numel(compHeights));
        compHeights       = [compHeights; [1.1; 1.4]*AnimalDatabase.GUI_BTNSIZE];
        tableHeight       = sum(compHeights) + (numel(compHeights) + 1)*AnimalDatabase.GUI_BORDER;
        set(obj.tbl.aniData, 'Heights', compHeights, 'Widths', compWidths);
        set(cntPlan, 'Heights', [0.7 1]*AnimalDatabase.GUI_BTNSIZE);
      end
      
      set(obj.cnt.details, 'Heights', [tableHeight, -1]);
      set(obj.cnt.aniInfo, 'Widths' , [tableHeight - numel(AnimalDatabase.ANI_ID_INFO)*elemSize, -1]);
      set(obj.cnt.dataScroll, 'MinimumHeights', tableHeight);
      
      
      %% Require user to enter all missing mandatory information before proceeding
      ctrlSupport         = [ctrlSupport{:}, dataSupport{:}, findall(obj.axs.aniImage, 'Type', 'uicontrol')'];
      ctrlState           = [idState{:}, dataState{:}];
      ctrlHandle          = [ctrlID{:}, ctrlData{:}];
      template            = arrayfun(@(x) get(x,'UserData'), ctrlHandle, 'UniformOutput', false);
      template            = cellfun(@(x) x{2}, template);
      ctrlLocation        = ctrlHandle(strcmpi({template.identifier}, 'whereAmI'));
      editable            = ctrlState ~= EntryState.DisplayOnly;
      needInput           = [ctrlHandle(ctrlState == EntryState.Invalid), ctrlHandle(ctrlState == EntryState.Suggested)];
      set(obj.btn.editAni, 'Callback', {@obj.editAnimalInfo, researcherID, animalID, ctrlHandle(editable), needInput, ctrlSupport, ctrlDate, hObject, ctrlLocation, isNewAni});

      if isempty(needInput)
        %% If there's nothing mandatory to be filled, proceed to showing daily info
        if isempty(logs) || ~any(arrayfun(@(x) isequal(when(1:3),x.date), logs))
          logs            = obj.pushDailyInfo(researcherID, animalID);
        end
        set([ctrlHandle, dataSupport{:}], 'Enable', 'inactive', 'BackgroundColor', EntryState.color(EntryState.DisplayOnly));
        obj.showDailyLog([], [], logs, animal);
      else
        %% Otherwise trigger edit mode
        executeCallback(obj.btn.editAni);
      end      
      
      %% Restore non-busy cursor
      obj.okImDone(alreadyBusy);
    end
    
    %----- Recreate the GUI display for the currently loaded daily log
    function showDailyLog(obj, hObject, event, logs, animal)
      %% Obtain logs if neccessary
      alreadyBusy         = obj.waitImWorking();
      what                = get(obj.tbl.aniDaily, 'UserData');
      researcherID        = what{1};
      animalID            = what{2};
      if isempty(hObject)
        when              = what{3}(1:3);
      else
        when              = get(hObject, 'String');
        when              = when{get(hObject, 'Value')};
        when              = obj.parseAsFormat(when, AnimalDatabase.SPECS_DATE);
      end
      if nargin < 4 || isempty(logs)
        [logs,animal]     = obj.pullDailyLogs(researcherID, animalID);
        if isempty(logs) || ~any(arrayfun(@(x) isequal(when(1:3),x.date), logs))
          logs            = pushDailyInfo(obj, researcherID, animalID);
        end
      end
      
      %% Select the desired log to display
      iDate               = find(arrayfun(@(x) isequal(when(1:3),x.date), logs));
      if isempty(iDate)
        error('AnimalDatabase:showDailyLog', 'Date %s not present in daily logs for %s (researcher %s).', obj.applyFormat(when,AnimalDatabase.SPECS_DATE), animalID, researcherID);
      elseif numel(iDate) > 1
        error('AnimalDatabase:showDailyLog', 'Multiple entries for date %present in daily logs for %s (researcher %s).', obj.applyFormat(when,AnimalDatabase.SPECS_DATE), animalID, researcherID);
      end
      
      %% Setup drop-down menu for accessing logs at different dates
      obj.btn.weighAni    = gobjects(0);
      delete(get(obj.tbl.aniDaily, 'Children'));
      
      uicontrol ( 'Parent'              , obj.tbl.aniDaily                  ...
                , 'Style'               , 'text'                            ...
                , 'String'              , 'Daily logs :'                    ...
                , 'FontSize'            , AnimalDatabase.GUI_FONT           ...
                , 'FontWeight'          , 'bold'                            ...
                , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG        ...
                , 'HorizontalAlignment' , 'right'                           ...
                , 'Interruptible'       , 'off'                             ...
                , 'BusyAction'          , 'cancel'                          ...
                );
      uicontrol ( 'Parent'              , obj.tbl.aniDaily                  ...
                , 'Style'               , 'popupmenu'                       ...
                , 'String'              , arrayfun(@(x) obj.applyFormat(x.date,AnimalDatabase.SPECS_DATE), logs, 'UniformOutput', false)   ...
                , 'Value'               , iDate                             ...
                , 'FontSize'            , AnimalDatabase.GUI_FONT           ...
                , 'FontWeight'          , 'bold'                            ...
                , 'HorizontalAlignment' , 'left'                            ...
                , 'Callback'            , @obj.showDailyLog                 ...
                , 'Interruptible'       , 'off'                             ...
                , 'BusyAction'          , 'cancel'                          ...
                );
      set(obj.tbl.aniDaily, 'Heights', 1.2*AnimalDatabase.GUI_BTNSIZE, 'Widths', [-1,-1]);
      
      %% Parse information table according to pre-specified templates
      template            = obj.tmplDailyInfo;
      animal              = obj.whatIsThePlan(animal, false);
      evalData            = {obj.suggestValues(template, logs(iDate), {animal}), animal};
      [ctrlHandle,ctrlState]  = obj.populateTable(obj.tbl.aniDaily, logs(iDate), template, {}, evalData, logs(iDate), AnimalDatabase.GUI_HEADER * 1.4);
      ctrlState           = [ctrlState{:}];
      ctrlHandle          = [ctrlHandle{:}];
      
      %% Setup weighing action
      if isempty(obj.btn.weighAni)
        error('AnimalDatabase:showDailyLog', 'Animal weighing button not found. Are you sure there is a daily log display template with WEIGH as the default value?');
      end
      set(obj.btn.weighAni, 'Callback', {@obj.weighThisOne, researcherID, animalID, ctrlHandle, evalData, nan});
      
      %% Decide on display vs. interaction
      thisDate            = datevec(now());
      needInput           = [ctrlHandle(ctrlState == EntryState.Invalid), ctrlHandle(ctrlState == EntryState.Suggested)];
      if isequal(when, thisDate(1:3))
        %% Ensure data validation before allowing use of the weigh button
        obj.waitForValidData(needInput, obj.btn.weighAni, gobjects(0), gobjects(0), false);
        if ~isempty(needInput)
          uicontrol(needInput(1));
        elseif ~isempty(ctrlHandle)
          uicontrol(ctrlHandle(end));
        end
        
      else
        %% If we're showing a past log, nothing can be edited
        set(obj.btn.weighAni, 'Enable', 'off');
        set(ctrlHandle, 'Enable', 'off');
        set(needInput, 'Enable', 'inactive', 'BackgroundColor', EntryState.color(EntryState.Invalid));
      end

      %% Restore non-busy cursor
      obj.checkUpdateTimer([], [], true);
      obj.okImDone(alreadyBusy);
    end
    

    %----- Callback to enter a blocking edit mode for animal details
    function editAnimalInfo(obj, hObject, event, researcherID, animalID, ctrlID, ctrlFocus, ctrlSupport, ctrlDate, ctrlAni, ctrlLocation, isNewAni)
      
      isOwner           = strcmpi(researcherID, get(obj.btn.responsible, 'UserData'));
      
      %% Create controls for uploading animal data
      delete(get(obj.tbl.aniDaily, 'Children'));
      obj.btn.weighAni  = gobjects(0);
      
      cntUpload         = uix.HButtonBox( 'Parent'            , obj.tbl.aniDaily                    ...
                                        , 'Spacing'           , 5*AnimalDatabase.GUI_BORDER         ...
                                        , 'ButtonSize'        , [7 1.5]*AnimalDatabase.GUI_BTNSIZE  ...
                                        , 'BackgroundColor'   , AnimalDatabase.CLR_GUI_BKG          ...
                                        );
      cntText           = uix.VBox( 'Parent', obj.tbl.aniDaily, 'Padding', 10*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
                          uicontrol( 'Parent', cntText, 'Style', 'text', 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      btnUpload         = uicontrol ( 'Parent'              , cntUpload                         ...
                                    , 'Style'               , 'pushbutton'                      ...
                                    , 'String'              , 'Upload animal info'              ...
                                    , 'FontSize'            , AnimalDatabase.GUI_FONT * 1.2     ...
                                    , 'Enable'              , 'off'                             ...
                                    , 'Callback'            , {@obj.uploadAniInfo, researcherID, animalID, ctrlID, ctrlSupport, ctrlDate, ctrlLocation, ctrlAni, isNewAni}  ...
                                    , 'Interruptible'       , 'off'                             ...
                                    , 'BusyAction'          , 'cancel'                          ...
                                    );
      btnCancel         = gobjects(0);
      if ~isNewAni
        btnCancel(end+1)= uicontrol ( 'Parent'              , cntUpload                         ...
                                    , 'Style'               , 'pushbutton'                      ...
                                    , 'String'              , 'Cancel editing'                  ...
                                    , 'FontSize'            , AnimalDatabase.GUI_FONT * 1.2     ...
                                    , 'Callback'            , {@obj.cancelEditAni, ctrlID, ctrlDate, ctrlAni}  ...
                                    , 'Interruptible'       , 'off'                             ...
                                    , 'BusyAction'          , 'cancel'                          ...
                                    );
      end
      if isOwner
        btnCancel(end+1)= uicontrol ( 'Parent'              , cntUpload                         ...
                                    , 'Style'               , 'pushbutton'                      ...
                                    , 'String'              , 'Delete animal'                   ...
                                    , 'FontSize'            , AnimalDatabase.GUI_FONT * 1.2     ...
                                    , 'Callback'            , {@obj.deleteAnimal, researcherID, animalID, ctrlID, ctrlDate, ctrlAni}  ...
                                    , 'Interruptible'       , 'off'                             ...
                                    , 'BusyAction'          , 'cancel'                          ...
                                    );
      end
      set(obj.tbl.aniDaily, 'Heights', [1.5*AnimalDatabase.GUI_BTNSIZE, -1], 'Widths', -1);
      
      %% Special case for a new handling plan, for which the effective date should be today
      if isNewAni || isempty(get(ctrlDate, 'String'))
        set(ctrlDate, 'String', obj.applyFormat(datevec(now()), AnimalDatabase.SPECS_DATE), 'BackgroundColor', get(obj.btn.responsible,'BackgroundColor'));
      end
      if isNewAni
        ctrlDate        = gobjects(0);
      end
      
      %% Enable the required controls and wait for user confirmation
      set(ctrlID, 'Enable', 'on');
      grayedOut         = arrayfun(@(x) isequal(get(x,'BackgroundColor'), EntryState.color(EntryState.DisplayOnly)), ctrlID);
      set(ctrlID(grayedOut), 'BackgroundColor', EntryState.color(EntryState.Valid));
      
      obj.waitForValidData(ctrlID, btnUpload, btnCancel, ctrlSupport, true, ctrlDate);
      if ~isempty(ctrlFocus)
        uicontrol(ctrlFocus(1));
      elseif ~isempty(ctrlID)
        uicontrol(ctrlID(end));
      end
      
    end
    
    
    %----- Callback to upload changes to the database 
   function uploadAniInfo(obj, hObject, event, researcherID, animalID, ctrlID, ctrlSupport, ctrlDate, ctrlLocation, ctrlAni, isNewAni)
      %% Retrieve user-entered data and update database
      [data, isValid, previously]               ...
                          = obj.getTableData(ctrlID);
      if any(~isValid)
        error('AnimalDatabase:uploadAniInfo', 'The entered information has invalid values.');
      end
      
      % Make sure we have an effective date for handling plans
      if ~isempty(ctrlDate)
        planDate          = obj.parseAsFormat(get(ctrlDate,'String'), AnimalDatabase.SPECS_DATE);
        if isempty(planDate)
          error('AnimalDatabase:uploadAniInfo', 'No effective date has been specified for the current handling plan.');
        end
        data.effective    = {planDate};
        previously.effective  = get(ctrlDate, 'UserData');
        previously.effective  = previously.effective{4};
      end
      
      %% Check for decommissioning or resuscitation of animals (only happens here if by the owner)
      if isfield(data,'status')
        %% Make sure to preserve future effective plans if we're changing plans for today
        if ~isempty(previously.effective) && datenum(data.effective{end}) < datenum(previously.effective)
          futurePlans     = {obj.tmplAnimal(strcmpi({obj.tmplAnimal.futurePlans}, 'yes')).identifier};
          for iPlan = 1:numel(futurePlans)
            data.(futurePlans{iPlan}){end+1}    ...
                          = previously.(futurePlans{iPlan});
          end
          % This only happens if there's a major status change, which takes effect also into the future
          [data.status{:}]= deal(data.status{end-1});
          % Assign location to owner by default so that one has to explicitly confirm via check in/out
          data.whereAmI   = researcherID;
        end
  
        %% Ensure that animals have an assigned cage and a consistent location
        if data.status{end} >= HandlingStatus.Dead
          %% Move dead and worse animals to never-never land
          data.cage       = AnimalDatabase.ANI_GRAVEYARD;
          data.whereAmI   = AnimalDatabase.ANI_ENDLOC;
          
        elseif any(data.status{end} == AnimalDatabase.EMERGENCY_STATUS)
          %% Not enforced for emergency state
          
        elseif strcmpi(data.cage, AnimalDatabase.ANI_GRAVEYARD)
          %% Force user to enter a valid cage name
          ctrlCage        = ctrlID(cellfun(@(x) strcmpi(x{2}.identifier,'cage'), get(ctrlID,'UserData')));
          set(ctrlCage, 'String', '');
          executeCallback(ctrlCage, 'KeyPressFcn');
          beep;
          return;
        end
      end
      
      %% Upload the new info and make sure we indicate a location for the animal
      [animal,researcher] = obj.pushAnimalInfo(researcherID, animalID, data);
      set(ctrlLocation, 'String', animal.whereAmI);
            
      %% Handle major changes in animal lists or status
      if isNewAni
        obj.somebodyArrived(researcher, animal);
        
      elseif isfield(data,'status')
        inEffect          = obj.whatIsThePlan(animal);
        if      inEffect.status       ~= previously.status                  ...
          &&  ( any(inEffect.status   == AnimalDatabase.EMERGENCY_STATUS)   ...
             || any(previously.status == AnimalDatabase.EMERGENCY_STATUS)   ...
              )
          if inEffect.status > HandlingStatus.WaterRestrictionOnly
            set(ctrlAni, 'BackgroundColor', HandlingStatus.color(inEffect.status));
          else
            set(ctrlAni, 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED);
          end
          obj.somebodyRedacted(researcher, animal, previously);
        end
      end
      
      
      %% Decide where the animal button is displayed and create a new cage if necessary
      inEffect            = obj.whatIsThePlan(animal, false);
      if inEffect.status >= HandlingStatus.AdLibWater
        hGroup            = obj.addDecommGroup();
      else
        hGroup            = obj.cnt.groupAni( strcmpi(get(obj.cnt.groupAni,'UserData'), data.cage) );
        if isempty(hGroup)
          hGroup          = obj.addAnimalGroup([], [], animal.cage);
        end
      end
      
      %% If the animal's group or status has changed, relocate the button
      hOrigin             = get(ctrlAni,'Parent');
      if hOrigin ~= hGroup
        obj.removeAniButton(ctrlAni);
        if isempty(get(hGroup, 'UserData'))
          obj.addDecommAnimal(hGroup, animal.ID, animal.status{end}, animal.imageFile);
        else
          hSibling        = get(get(hGroup,'Parent'), 'Children');
          hSibling( hSibling == hGroup )  = [];
          obj.addAnimal(get(hSibling,'Children'), [], hGroup, animal.ID, animal.status{end}, animal.imageFile);
        end
        
        %% Reapply layout
        cntDecomm         = obj.cnt.groupAni( arrayfun(@(x) isempty(get(x,'UserData')), obj.cnt.groupAni) );
        if isempty(cntDecomm)
          AnimalDatabase.layoutScrollablePanels(obj.cnt.aniGroups);
        else
          AnimalDatabase.layoutButtonGrid(cntDecomm);
        end
      end
      
      %% Restore enabled state of other controls and remove keypress traps
      AnimalDatabase.restoreInteractivity(hObject, ctrlID, ctrlDate);
      set(ctrlSupport, 'Enable', 'off');
      
      %% Display daily logs and a button to re-enter edit mode
      obj.pullAnimalList(researcherID);
      obj.showDailyLog([], []);
    end
      
    %----- Callback to cancel an ongoing animal information edit
    function cancelEditAni(obj, hObject, event, ctrlID, ctrlDate, ctrlAni)
      AnimalDatabase.restoreInteractivity(hObject, ctrlID, ctrlDate);
      executeCallback(ctrlAni);
    end    
    
    %----- Callback to delete an animal from the database
    function deleteAnimal(obj, hObject, event, researcherID, animalID, ctrlID, ctrlDate, ctrlAni)
      %% Allow unprompted deletion of new animals, otherwise require the user to confirm
      list                = obj.pullAnimalList(researcherID);
      iAnimal             = find(strcmpi({list.ID}, animalID));
      if isempty(iAnimal)
        %% Execute the callback that actually deletes the animal
        obj.reallyDeleteAnimal(hObject, event, researcherID, animalID, ctrlID, ctrlDate, ctrlAni, iAnimal);
        
      else
        %% Create a warning message 
        ctrl              = get(obj.tbl.aniDaily, 'Children');
        ctrl              = get(ctrl(1), 'Children');
        set( ctrl   , 'Style'                   , 'text'                                                                              ...
                    , 'String'                  , { ['You are about to delete animal ' animalID ' of researcher ' researcherID '! ']  ...
                                                  , ''                                                                                ...
                                                  [ 'This will destroy all records of it in the database, although the water logs '   ...
                                                    'sheet will only be renamed with a "DELETED" prefix.'                             ...
                                                  ] }                                                                                 ...
                    , 'HorizontalAlignment'     , 'left'                                                                              ...
                    , 'FontSize'                , AnimalDatabase.GUI_FONT + 2                                                         ...
                    , 'ForegroundColor'         , AnimalDatabase.CLR_ALERT                                                            ...
                    , 'BackgroundColor'         , AnimalDatabase.CLR_GUI_BKG                                                          ...
                    );
                  
        %% Change the callback of this button to require that the user confirm
        set ( hObject                                               ...
            , 'String'          , 'CONFIRM delete'                  ...
            , 'ForegroundColor' , AnimalDatabase.CLR_ALERT          ...
            , 'Callback'        , {@obj.reallyDeleteAnimal, researcherID, animalID, ctrlID, ctrlDate, ctrlAni, iAnimal}   ...
            );
      end
    end
    
    %----- Callback to delete an animal from the database
    function reallyDeleteAnimal(obj, hObject, event, researcherID, animalID, ctrlID, ctrlDate, ctrlAni, iAnimal)
      %% If the animal exists in the database, remove it
      if ~isempty(iAnimal)
        %% Modify watering logs structure
        researcher              = obj.pullLogsStructure(researcherID, true);
        sheetProps              = [researcher.logStructure.sheets.properties];
        aniProps                = sheetProps(strcmpi({sheetProps.title}, animalID));
        delTitle                = ['DELETED ' animalID];
        
        if ~isempty(aniProps)
          %% If a DELETED sheet already exists for this animal, delete it
          delProps              = sheetProps(strcmpi({sheetProps.title}, delTitle));
          if ~isempty(delProps)
            mat2sheets(researcher.wateringLogs, ['!' num2str(delProps.sheetId)]);
          end
        
          %% Rename the animal's watering sheet
          mat2sheets(researcher.wateringLogs, num2str(aniProps.sheetId), delTitle);
        end
        
        %% Locate animal's row in the researcher's animal list; always update to be safe
        animals                 = obj.pullAnimalList(researcherID);
        iAnimal                 = find(strcmpi({animals.ID}, animalID));
        if ~isempty(iAnimal)
          mat2sheets(AnimalDatabase.DATABASE_ID, researcher.animalsGID, [-(iAnimal + 1), 0]);
        end
      end
      
      
      %% Delete the button associated with the animal and show the next available one
      AnimalDatabase.restoreInteractivity(hObject, ctrlID, ctrlDate);
      obj.removeAniButton(ctrlAni);
      obj.nextInLine(hObject, event, researcherID);
    end    
    
    %----- Remove the button associated with a given animal
    function removeAniButton(obj, ctrlAni)
      ctrlAdd             = get(ctrlAni, 'UserData');
      if ~isempty(ctrlAdd{2})
        set(ctrlAdd{2}, 'Visible', 'on');
      end
      
      obj.btn.aniInfo(obj.btn.aniInfo == ctrlAni) = [];
      delete(ctrlAni);
    end    

    
    %----- Callback to confirm flagging an animal to be in one of the emergency statuses
    function majorStatusChange(obj, hObject, event, researcherID, animal, status, ctrlAni)
      set ( hObject                                                   ...
          , 'String'              , ['CONFIRM ' char(status)]         ...
          , 'FontWeight'          , 'bold'                            ...
          , 'ForegroundColor'     , HandlingStatus.color(status)      ...
          , 'BackgroundColor'     , [1 1 1]*0.4                       ...
          , 'Callback'            , {@obj.somethingHappened, researcherID, animal, status, ctrlAni} ...
          );
    end
    
    %----- Flag one or more animals as being in one of the emergency statuses
    function somethingHappened(obj, hObject, event, researcherID, animal, status, ctrlAni)
      alreadyBusy         = obj.waitImWorking();
      
      %% Get the latest plans for the animals and which fields correspond to future plans
      if ~isstruct(animal)
        animal            = obj.findAnimal(researcherID, animal, true);
      end
      if numel(status) == 1
        status            = repmat(status, size(animal));
      end
      futurePlans         = {obj.tmplAnimal(strcmpi({obj.tmplAnimal.futurePlans}, 'yes')).identifier};
      when                = now();
      dateStamp           = datevec(when);
      dateStamp           = dateStamp(1:3);

      %% Loop through animals
      for iAni = 1:numel(animal)
        %% Insert a status change effective today and into the future, if those plans have been made
        effective         = cellfun(@(x) datenum(x), animal(iAni).effective);
        iPast             = find(effective <  when, 1, 'last' );
        iPresent          = find(effective == when, 1, 'last' );
        iFuture           = find(effective >  when, 1, 'first');
        if isempty(iPast)
          iPast           = 0;
        end
        if ~isempty(iFuture)
          %% The future begins one day from now i.e. 2 slots from the immediate past
          range           = 0:numel(effective) - iFuture;
          for iPlan = 1:numel(futurePlans)
            animal(iAni).(futurePlans{iPlan})(iPast + 2 + range)    ...
                          = animal(iAni).(futurePlans{iPlan})(iFuture + range);
          end
        end
        
        %% If there were no prior plans effective today, copy the past plan (which must exist)
        if isempty(iPresent)
          iPresent        = iPast + 1;
          for iPlan = 1:numel(futurePlans)
            animal(iAni).(futurePlans{iPlan})(iPresent)             ...
                          = animal(iAni).(futurePlans{iPlan})(iPast);
          end
        end
        animal(iAni).effective{iPresent}    = dateStamp;
        [animal(iAni).status{iPresent:end}] = deal(status(iAni));

        %% Move dead and worse animals to never-never land
        if status(iAni) >= HandlingStatus.Dead
          animal(iAni).cage                 = AnimalDatabase.ANI_GRAVEYARD;
          animal(iAni).whereAmI             = AnimalDatabase.ANI_ENDLOC;
        end
        
        %% Upload the new info per mouse 
        data              = futurePlans;
        data(end+1,:)     = cellfun(@(x) animal(iAni).(x), futurePlans, 'UniformOutput', false);
        animal(iAni)      = obj.pushAnimalInfo(researcherID, animal(iAni).ID, data{:});

        %% notify the researcher of an emergency-level change in status (dead/missing)
        notifyAnimalStatusChange(animal(iAni),'researcher',[],obj);
        
        %% Update the animal display
        if ~isempty(ctrlAni)
          set(ctrlAni, 'BackgroundColor', HandlingStatus.color(animal(iAni).status{end}));
          executeCallback(ctrlAni);
        end
      end
      
      %% Restore non-busy cursor
      obj.okImDone(alreadyBusy);
    end
    
    %----- Called whenever a new animal is added; can only be done by the owner of the animal
    function somebodyArrived(obj, researcher, animal)
      notifyNewAnimal(animal,obj);
    end
    
    %----- Called whenever an emergency-level status is redacted; can only be done by the owner of the animal
    function somebodyRedacted(obj, researcher, animal, previousInfo)
      notifyAnimalStatusChange(animal,'tech',previousInfo,obj);
    end
    
    
    %----- Add an animal group panel to the GUI
    function [cntGroup, btnAdd] = addAnimalGroup(obj, hObject, event, groupName)
      %% If no group info is provided, prompt the user
      if nargin < 4
        %% Input validator to ensure that group names are unique
        currentGroups         = get(obj.cnt.groupAni, 'UserData');
        validator             = {@notInListValidator, currentGroups, 'Cannot be the same as existing cages.', @strcmpi};
        groupName             = validatedInputDialog( 'Add cage', 'New cage name:', [], validator, [], true     ...
                                                    , AnimalDatabase.GUI_FONT, [], AnimalDatabase.GUI_MONITOR   ...
                                                    );
        if isempty(groupName)
          return;
        end
      end
      
      
      %% Create a panel for the group
      obj.pnl.aniGroup(end+1) = uix.Panel     ( 'Parent'              , obj.cnt.aniGroups                   ...
                                              , 'Title'               , groupName                           ...
                                              , 'FontSize'            , AnimalDatabase.GUI_FONT             ...
                                              , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG          ...
                                              , 'UserData'            , 4.5*AnimalDatabase.GUI_BTNSIZE      ...
                                              );
      cntButtons              = uix.HBox      ( 'Parent'              , obj.pnl.aniGroup(end)               ...
                                              , 'Spacing'             , AnimalDatabase.GUI_BORDER           ...
                                              , 'Padding'             , 2*AnimalDatabase.GUI_BORDER         ...
                                              , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG          ...
                                              , 'UserData'            , groupName                           ...
                                              );
      obj.cnt.groupAni(end+1) = uix.HButtonBox( 'Parent'              , cntButtons                          ...
                                              , 'Spacing'             , AnimalDatabase.GUI_BORDER           ...
                                              , 'ButtonSize'          , [3 3]*AnimalDatabase.GUI_BTNSIZE    ...
                                              , 'HorizontalAlignment' , 'left'                              ...
                                              , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG          ...
                                              , 'UserData'            , groupName                           ...
                                              );
      cntAdd                  = uix.HButtonBox( 'Parent'              , cntButtons                          ...
                                              , 'Spacing'             , AnimalDatabase.GUI_BORDER           ...
                                              , 'ButtonSize'          , [1 2]*AnimalDatabase.GUI_BTNSIZE    ...
                                              , 'HorizontalAlignment' , 'left'                              ...
                                              , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG          ...
                                              , 'UserData'            , groupName                           ...
                                              );
      cntGroup                = obj.cnt.groupAni(end);
                                          
      %% Legend for the animal button
      infoBkg                 = reshape(AnimalDatabase.CLR_GUI_BKG, 1, 1, []);
      infoBkg                 = repmat(infoBkg, 3*AnimalDatabase.GUI_BTNSIZE, 3*AnimalDatabase.GUI_BTNSIZE, 1);
                              uicontrol     ( 'Parent'              , obj.cnt.groupAni(end)                 ...
                                            , 'Style'               , 'pushbutton'                          ...
                                            , 'String'              , '<html><div style="text-align:right"><br/>tech duty<br/>earned<br/>need</div></html>' ...
                                            , 'FontSize'            , AnimalDatabase.GUI_FONT               ...
                                            , 'Enable'              , 'inactive'                            ...
                                            , 'CData'               , infoBkg                               ...
                                            , 'ForegroundColor'     , [1 1 1]*0.6                           ...
                                            , 'Interruptible'       , 'off'                                 ...
                                            , 'BusyAction'          , 'cancel'                              ...
                                            );

      %% Animal addition button if user is the owner and the group is not full
      hOwner                  = obj.btn.showWhose(arrayfun(@(x) get(x,'Value'), obj.btn.showWhose) == 1);
      researcherID            = get(hOwner, 'UserData');
      if strcmpi(researcherID, get(obj.btn.responsible, 'UserData'))
        obj.btn.aniAdd(end+1) = uicontrol ( 'Parent'            , cntAdd                                    ...
                                          , 'Style'             , 'pushbutton'                              ...
                                          , 'String'            , '+'                                       ...
                                          , 'FontSize'          , AnimalDatabase.GUI_FONT * 1.4             ...
                                          , 'Callback'          , {@obj.addAnimal, cntGroup}                ...
                                          , 'BackgroundColor'   , AnimalDatabase.CLR_ADD_BTN                ...
                                          , 'UserData'          , obj.cnt.groupAni(end)                     ...
                                          , 'Interruptible'     , 'off'                                     ...
                                          , 'BusyAction'        , 'cancel'                                  ...
                                          );
        btnAdd                = obj.btn.aniAdd(end);
      else
        btnAdd                = gobjects(0);
      end
      
      %% Ensure that decommissioned groups are last and impose a more uniform size of panels
      hPanels                 = get(obj.cnt.aniGroups, 'Children');
      isDecomm                = arrayfun(@(x) isempty(get(get(x,'Children'),'UserData')), hPanels);
      if any(isDecomm)
        set(obj.cnt.aniGroups, 'Children', [hPanels(isDecomm); hPanels(~isDecomm)]);
      end
      
      set( cntButtons, 'Widths', [-1, AnimalDatabase.GUI_BTNSIZE] );
      AnimalDatabase.layoutScrollablePanels(obj.cnt.aniGroups);
    end
    
    %----- Add an animal to a given group panel in the GUI
    function addAnimal(obj, hObject, event, hGroup, animalID, aniStatus, imageFile)
      hOwner                  = obj.btn.showWhose(arrayfun(@(x) get(x,'Value'), obj.btn.showWhose) == 1);
      researcherID            = get(hOwner, 'UserData');
      
      %% If no animal ID is provided, prompt the user
      if nargin < 5
        %% Input validator to ensure that group names are unique
        animals               = obj.pullAnimalList(researcherID);
        validator             = {@notInListValidator, {animals.ID}, 'Cannot be the same as other animals.', @strcmpi};
        animalID              = validatedInputDialog( 'Add animal', 'New animal ID:', [], validator, [], true   ...
                                                    , AnimalDatabase.GUI_FONT, [], AnimalDatabase.GUI_MONITOR   ...
                                                    );
        if isempty(animalID)
          return;
        end
        
        newAnimal             = AnimalDatabase.emptyLike(obj.tmplAnimal, {''});
        newAnimal.ID          = animalID;
        newAnimal.cage        = get(hGroup, 'UserData');
        newAnimal.imageFile   = [];
        newAnimal.owner       = researcherID;
        aniStatus             = HandlingStatus.Unknown;
        imageFile             = [];
        
      else
        newAnimal             = [];
      end
    
      %% Create a control for showing details of the animal
      obj.btn.aniInfo(end+1)  = uicontrol ( 'Parent'            , hGroup                              ...
                                          , 'Style'             , 'togglebutton'                      ...
                                          , 'String'            , animalID                            ...
                                          , 'FontSize'          , AnimalDatabase.GUI_FONT             ...
                                          , 'UserData'          , {animalID, hObject}                 ...
                                          , 'Callback'          , {@obj.showAnimalDetails, researcherID, animalID}  ...
                                          , 'Interruptible'     , 'off'                               ...
                                          , 'BusyAction'        , 'cancel'                            ...
                                          );
      if aniStatus > HandlingStatus.WaterRestrictionOnly
        set(obj.btn.aniInfo(end), 'BackgroundColor', HandlingStatus.color(aniStatus));
      end
      if numel(get(hGroup,'Children')) > AnimalDatabase.MAX_ANI_GROUP && ~isempty(hObject)
        set(hObject, 'Visible', 'off');
      end
      
      %% Show some basic animal information in the tooltip
      if ~isempty(imageFile) && exist(imageFile,'file')
        info                  = { ['<center><img src="file:/' imageFile '"></center>']                ...
                                };
        set(obj.btn.aniInfo(end), 'TooltipString', ['<html><div style="font-size:14px">', strjoin(info,' '), '</div></html>']);
      end
      
      %% Trigger edit mode for information about the new animal, if relevant
      if ~isempty(newAnimal)
        obj.showAnimalDetails(obj.btn.aniInfo(end), event, researcherID, animalID, newAnimal, true);
      end
    end
    
    %----- Add a simplified group panel for decommissioned animals
    function cntGroup = addDecommGroup(obj, animal)
      cntGroup                = obj.cnt.groupAni( arrayfun(@(x) isempty(get(x,'UserData')), obj.cnt.groupAni) );
      if ~isempty(cntGroup)
        return;
      end
      if nargin < 2
        animal                = [];
      end
      
      %% Create a panel for the group if it doesn't already exists
      obj.pnl.aniGroup(end+1) = uix.Panel ( 'Parent'              , obj.cnt.aniGroups                 ...
                                          , 'Title'               , '(Decommissioned)'                ...
                                          , 'FontSize'            , AnimalDatabase.GUI_FONT           ...
                                          , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG        ...
                                          );
      obj.cnt.groupAni(end+1) = uix.Grid  ( 'Parent'              , obj.pnl.aniGroup(end)             ...
                                          , 'Spacing'             , AnimalDatabase.GUI_BORDER         ...
                                          , 'Padding'             , 2*AnimalDatabase.GUI_BORDER       ...
                                          , 'BackgroundColor'     , AnimalDatabase.CLR_GUI_BKG        ...
                                          );
      cntGroup                = obj.cnt.groupAni(end);

      %% Sort animals by status
      info                    = [num2cell(double([animal.status])); {animal.ID}]';
      [~,iOrder]              = sortrows(info);
      animal                  = animal(iOrder);
      
      %% Add a button per animal
      for iAni = 1:numel(animal)
        obj.addDecommAnimal(obj.cnt.groupAni(end), animal(iAni).ID, animal(iAni).status, animal(iAni).imageFile);
      end
      
      AnimalDatabase.layoutButtonGrid(obj.cnt.groupAni(end));
    end
    
    %----- Add a decommissioned animal to a given group
    function addDecommAnimal(obj, hParent, animalID, aniStatus, imageFile)
      hOwner                  = obj.btn.showWhose(arrayfun(@(x) get(x,'Value'), obj.btn.showWhose) == 1);
      researcherID            = get(hOwner, 'UserData');
      obj.btn.aniInfo(end+1)  = uicontrol ( 'Parent'            , hParent                                   ...
                                          , 'Style'             , 'togglebutton'                            ...
                                          , 'String'            , animalID                                  ...
                                          , 'FontSize'          , AnimalDatabase.GUI_FONT                   ...
                                          , 'TooltipString'     , ['<html><div style="font-size:14px">' char(aniStatus) '</div></html>']  ...
                                          , 'BackgroundColor'   , HandlingStatus.color(aniStatus)           ...
                                          , 'UserData'          , {animalID, []}                            ...
                                          , 'Callback'          , {@obj.showAnimalDetails, researcherID, animalID}                        ...
                                          , 'Interruptible'     , 'off'                                     ...
                                          , 'BusyAction'        , 'cancel'                                  ...
                                          );
    end
    
    
    %----- Disable all other controls until the user has entered valid information in all controls
    function otherCtrl = waitForValidData(obj, ctrl, hCommit, hCancel, hSupport, disableOthers, hDate)
      if nargin < 6 || isempty(disableOthers)
        disableOthers         = true;
      end
      if nargin < 7
        hDate                 = [];
      end
      
      %% Disable all other controls in the figure
      allCtrl                 = findall(obj.figGUI, 'Type', 'uicontrol', 'Enable', 'on');
      otherCtrl               = setdiff(allCtrl, [ctrl(:); hCommit(:); hCancel(:); hSupport(:)]);
      otherCtrl(arrayfun(@(x) strcmpi(get(x,'Style'), 'text'), otherCtrl)) = [];
      if disableOthers
        set(otherCtrl, 'Enable', 'off');
        set(hSupport , 'Enable', 'on');
      end
      
      %% Setup keypress detection for all implicated controls to validate their data
      isValid                 = false(size(ctrl));
      for iCtrl = 1:numel(ctrl)
        %% Special case for checkboxes
        if strcmpi(get(ctrl(iCtrl), 'Style'), 'text')
          check               = AnimalDatabase.getSibling(ctrl(iCtrl));
          set ( check                                                                           ...
              , 'Callback'      , {@obj.validateCheckbox, iCtrl, ctrl(iCtrl), hCommit, -1}      ...
              , 'ButtonDownFcn' , {@obj.validateCheckbox, iCtrl, ctrl(iCtrl), hCommit,  1}      ...
              );
          [~,isValid(iCtrl)]  = obj.getTableData(check);
          continue;
        end
        
        %% Use keypress trap only for single-line edit boxes
        if strcmpi(get(ctrl(iCtrl), 'Style'), 'edit') && get(ctrl(iCtrl), 'Max') <= get(ctrl(iCtrl), 'Min') + 1
          callback            = 'KeyPressFcn';
          keypressHack        = true;
        else
          callback            = 'Callback';
          keypressHack        = false;
        end
        
        %% Update date display only for futurePlans
        template              = get(ctrl(iCtrl), 'UserData');
        template              = template{2};
        if isfield(template,'futurePlans') && strcmpi(template.futurePlans, 'yes')
          hUpdate             = hDate;
        else
          hUpdate             = [];
        end
        
        %% Set callback
        set(ctrl(iCtrl), callback, {@obj.validateData, iCtrl, hCommit, keypressHack, hUpdate});
        [~,isValid(iCtrl)]    = obj.getTableData(ctrl(iCtrl));
      end
      
      %% Set the state of the commit button depending on data validity
      for hAction = [hCommit, hCancel]
        userData              = get(hAction, 'UserData');
        if isempty(userData)
          userData            = {isValid, otherCtrl};
        else
          userData            = {isValid, otherCtrl, userData};
        end
        set(hAction, 'UserData', userData);
      end
      
      if all(isValid)
        set(hCommit, 'Enable', 'on');
      else
        set(hCommit, 'Enable', 'off');
      end
    end
    
    
    %------ Set the state of GUI buttons depending on whether we have a scale connected
    function setScaleState(obj, serialPorts)
      
      if ~isfield(obj.btn, 'weighMode') || ~ishghandle(obj.btn.weighMode)
        return;
      end
            
      if ~isempty(obj.eScale) && obj.eScale.success
        set( obj.btn.weighMode, 'Value', 0, 'Style', 'togglebutton', 'String', 'Weighing Mode', 'Callback', @obj.toggleScaleTimer, 'ButtonDownFcn', @obj.disconnectScale  ...
           , 'TooltipString', '<html><div style="font-size:14px">Automatic animal weighing when scale readout crosses threshold<br/>Right-click to disconnect scale and use manual entry</div></html>' );
        
      elseif nargin > 1
        set( obj.btn.weighMode, 'Style', 'pushbutton', 'String', sprintf('No scale in %d serial port(s)',numel(serialPorts)), 'Callback', @obj.connectToScale             ...
           , 'TooltipString', '<html><div style="color:red; font-size:14px"><b>No electronic scale found, connect one and try again</b></div></html>' );
%            , 'Callback', @obj.buttonDisabled, 'ForegroundColor', AnimalDatabase.CLR_DISABLED_TXT, 'BackgroundColor', AnimalDatabase.CLR_DISABLED_BKG );
%         AnimalDatabase.setBorderByState(obj.btn.weighMode);

      else
        set( obj.btn.weighMode, 'Style', 'pushbutton', 'String', 'Connect Electronic Scale', 'Callback', @obj.connectToScale                                              ...
           , 'TooltipString', '<html><div style="color:red; font-size:14px"><b>An electronic scale needs to be connected to perform semi-automated weighing</b></div></html>' );
      end
      set(obj.btn.weighMode, 'UserData', 0);

    end
    
    %----- Validation function for use entry of weights that should be close enough to a previous value
    function [answer, complaint] = weightInputValidator(obj, input, eventData, refValue)
      answer            = str2double(input);
      refDiff           = (answer - refValue) / refValue;
      if ~isfinite(answer) || ~(answer > 0)
        answer          = [];
        complaint       = 'Input must be a positive number';
      elseif ~obj.complained && abs(refDiff) > AnimalDatabase.MAX_WEIGHT_DIFFERENCE
        complaint       = sprintf('%.3g%% difference from previously (%.4gg) -- are you sure it''s the same mouse?', refDiff*100, refValue);
        obj.complained  = true;
      else
        complaint       = '';
      end
    end

    %----- Callback to enter weighing mode for the currently displayed animal
    function weighThisOne(obj, hObject, event, researcherID, animalID, ctrlLog, evalData, alreadyGiven, readEScale, ~)
      
      %% Default arguments and supporting GUI controls
      if nargin < 9
        readEScale    = false;
      end
      
      hWeight         = get(hObject, 'UserData');
      hWeight         = hWeight{3};
      jWeight         = findjobj(hWeight);
      specs           = get(hWeight, 'UserData');
      template        = specs{2};
      
      hasEScale       = ~isempty(obj.eScale) && obj.eScale.success;
      pollingScale    = ~isempty(obj.tmrPollScale) && strcmpi(get(obj.tmrPollScale,'Running'), 'on');
      alreadyBusy     = [];
      
      
      %% Get information about what's expected for this animal
      obj.checkUpdateTimer([], [], true);
      animal          = obj.findAnimal(researcherID, animalID);
      if isempty(animal.rightNow) || ~isfinite(animal.rightNow.weight)
        refWeight     = animal.initWeight;
        isRepeat      = false;
      else
        refWeight     = animal.rightNow.weight;
        isRepeat      = ~isnan(animal.rightNow.received)                                        ...
                     && animal.rightNow.date == AnimalDatabase.datenum2date(datevec(now()))     ...
                      ;
      end
      
      %% Obtain the animal's weight
      if ~hasEScale || (pollingScale && readEScale <= 1 && isnan(obj.scaleReading))
        %% No electronic scale or invalid reading from scale, default to manual entry
        aniWeight       = validatedInputDialog( ['Weigh ' animalID], sprintf('Weight for %s (researcher %s):', animalID, researcherID)            ...
                                              , [], @positiveInputValidator                                                                       ...
                                              , { @withinRangeConfirmation, refWeight, AnimalDatabase.MAX_WEIGHT_DIFFERENCE                       ...
                                                , 'This is %.3g%% different from previously (%.4gg) -- are you sure it''s the correct animal?'}   ...
                                              , true, AnimalDatabase.GUI_FONT, [], AnimalDatabase.GUI_MONITOR                                     ...
                                              );
        if isempty(aniWeight)
          return;
        end

        alreadyBusy     = obj.waitImWorking();
        
      elseif ~pollingScale
        %% Start polling electronic scale for a one-shot readout
        set(obj.btn.weighMode, 'Value', 1);
        obj.toggleScaleTimer([], [], true);
        return;
        
      elseif isRepeat && isempty(event)
        %% Repeated measurement of the same animal on the same day, require user to confirm
        set(hWeight, 'String', obj.applyFormat(obj.scaleReading, template.data));
        jWeight.setBorder(javax.swing.border.LineBorder(java.awt.Color(AnimalDatabase.CLR_ALERT(1),AnimalDatabase.CLR_ALERT(3),AnimalDatabase.CLR_ALERT(3)), 3, false));
        
        set ( hObject, 'String', sprintf('CONFIRM repeated weighing  (was %.3gg)', refWeight)                                                                 ...
            , 'ForegroundColor', AnimalDatabase.CLR_ALERT, 'Callback', {@obj.weighThisOne, researcherID, animalID, ctrlLog, evalData, nan, obj.scaleReading}  ...
            );
        set(get(hObject,'Parent'), 'Widths', [-1, 12*AnimalDatabase.GUI_BTNSIZE]);
        return;
        
      elseif abs(readEScale) == 1 && abs(obj.scaleReading - refWeight) > AnimalDatabase.MAX_WEIGHT_DIFFERENCE*refWeight
        %% Reading is too different from reference, require user to confirm
        set(hWeight, 'String', obj.applyFormat(obj.scaleReading, template.data));
        jWeight.setBorder(javax.swing.border.LineBorder(java.awt.Color(AnimalDatabase.CLR_ALERT(1),AnimalDatabase.CLR_ALERT(3),AnimalDatabase.CLR_ALERT(3)), 3, false));
        
        set ( hObject, 'String', sprintf('CONFIRM weight  (%.3g%% discrepancy)', 100*(obj.scaleReading/refWeight - 1))                                        ...
            , 'ForegroundColor', AnimalDatabase.CLR_ALERT, 'Callback', {@obj.weighThisOne, researcherID, animalID, ctrlLog, evalData, nan, obj.scaleReading}  ...
            );
        set(get(hObject,'Parent'), 'Widths', [-1, 12*AnimalDatabase.GUI_BTNSIZE]);
        beep;
        
        return;
        
      elseif readEScale <= 1
        %% Valid reading from an electronic scale
        aniWeight       = obj.scaleReading;
      
      elseif isempty(event)
        %% In case a CONFIRM message was shown, require the user to physically click the button
        if ~isnan(obj.scaleReading)
          set(hWeight, 'String', obj.applyFormat(obj.scaleReading, template.data));
          set ( hObject, 'String', sprintf('CONFIRM weight  (%.3g%% discrepancy)', 100*(obj.scaleReading/refWeight - 1))                                        ...
              , 'ForegroundColor', AnimalDatabase.CLR_ALERT, 'Callback', {@obj.weighThisOne, researcherID, animalID, ctrlLog, evalData, nan, obj.scaleReading}  ...
              );
        end
        return;
      
      elseif isnan(obj.scaleReading)
        %% HACK for user to confirm a previous discrepant reading without retaking it
        aniWeight       = readEScale;
        
      else
        %% User confirmed re-take
        aniWeight       = obj.scaleReading;
      
      end
      
      % If we get here, flag that any current changes are being attended to
      set(obj.btn.weighMode, 'UserData', 0);
      

      %% Write weight into associated display box, and retrieve all entered data 
      set(hWeight, 'String', obj.applyFormat(aniWeight, template.data));
      jWeight.setBorder(javax.swing.border.LineBorder(java.awt.Color(AnimalDatabase.CLR_SELECT(1),AnimalDatabase.CLR_SELECT(2),AnimalDatabase.CLR_SELECT(3)), 2, false));
      
      data            = obj.getTableData(ctrlLog);
      if ~isnan(alreadyGiven)
        data.supplement = data.supplement + alreadyGiven;
      end
      evalData        = [{data}, evalData];
      
      %% Update formulaic quantities, including the amount of water received
      for iCtrl = 1:numel(ctrlLog)
        if ctrlLog(iCtrl) == hWeight
          continue;
        end
        
        specs         = get(ctrlLog(iCtrl), 'UserData');
        state         = specs{1};
        template      = specs{2};
        if strcmp(template.identifier, 'weighPerson')
          %% Record who did the weighing
          set(ctrlLog(iCtrl), 'String', get(obj.btn.responsible, 'UserData'));

        elseif strcmp(template.identifier, 'weighTime')
          %% Record what time the weighing happened
          set(ctrlLog(iCtrl), 'String', obj.applyFormat(AnimalDatabase.datenum2time(now()), template.data));
          
        elseif strcmp(template.identifier, 'weighLocation')
          %% Record where the weighing happened
          set(ctrlLog(iCtrl), 'String', obj.whoAmI);
          
        elseif state == EntryState.DisplayOnly && ~isempty(strfind(template.data{3}, '$'))
          %% Display calculated quantities
          value       = obj.suggestedForFormat(template.data, evalData);
          set(ctrlLog(iCtrl), 'String', obj.applyFormat(value, template.data));
        end
      end

      %% Update data with the computed quantities, and allow editing now
      data            = obj.getTableData(ctrlLog);
      if ~isnan(alreadyGiven)
        data.supplement = data.supplement + alreadyGiven;
      end
      
      otherCtrl       = get(hObject, 'UserData');
      set(otherCtrl{2}, 'Enable', 'on');

      %% Indicate that the supplement has been given and the amount of received water has increased
      txtSupplement   = findall(obj.tbl.aniDaily, 'Type', 'uicontrol', 'Style', 'text', 'UserData', 'supplement');
      description     = sprintf('<html>%s&nbsp;&nbsp;<font color="blue"><b>%.4g +</b></font></html>', get(txtSupplement,'String'), data.supplement);
      set(txtSupplement, 'String', description, 'Style', 'togglebutton', 'Enable', 'inactive', 'HorizontalAlignment', 'right', 'FontSize', AnimalDatabase.GUI_FONT + 2);
      AnimalDatabase.setBorderByState(txtSupplement);

      identifier      = arrayfun(@(x) get(x,'UserData'), ctrlLog, 'UniformOutput', false);
      edtSupplement   = ctrlLog(cellfun(@(x) strcmp(x{2}.identifier,'supplement'), identifier));
      set(edtSupplement, 'String', '0');

      %% Check if weight is acceptable, otherwise prompt the user to give supplements
      animal          = obj.findAnimal(researcherID, animalID);
      doNotify        = false;
      [lowWeight,iWantMore,veryLowWeight] = hasLowWeight(data, animal, refWeight);
              
      if ~lowWeight 
        %% All's well 
        
      elseif isnan(alreadyGiven)
        %% In case of the first attempt, indicate that supplement has been given but more is required
        info          = get(edtSupplement, 'UserData');
        info{3}       = sprintf('%.4g', iWantMore);
        set(edtSupplement, 'String', info{3}, 'UserData', info, 'FontWeight', 'bold', 'BackgroundColor', EntryState.color(EntryState.Invalid), 'FontSize', AnimalDatabase.GUI_FONT + 2);
        
        set ( hWeight, 'FontSize', AnimalDatabase.GUI_FONT + 2, 'FontWeight', 'bold', 'ForegroundColor', AnimalDatabase.CLR_ALERT );
        set ( hObject, 'String', 'Too thin! Give more water and RE-WEIGH', 'FontSize', AnimalDatabase.GUI_FONT + 2                                                          ...
            , 'ForegroundColor', AnimalDatabase.CLR_ALERT, 'Callback', {@obj.weighThisOne, researcherID, animalID, ctrlLog, evalData, data.supplement, -abs(readEScale)}    ...
            );
        set(get(hObject,'Parent'), 'Widths', [-1, 13*AnimalDatabase.GUI_BTNSIZE]);
        jWeight.setBorder(javax.swing.border.LineBorder(java.awt.Color(AnimalDatabase.CLR_ALERT(1),AnimalDatabase.CLR_ALERT(3),AnimalDatabase.CLR_ALERT(3)), 3, false));

        if (data.supplement > 0)
          otherCtrl   = get(hObject, 'UserData');
          set(otherCtrl{2}( otherCtrl{2} ~= edtSupplement ), 'Enable', 'off');
        end
        uicontrol(edtSupplement);
        obj.okImDone(alreadyBusy);
        beep;
        return;

      else
        %% In case of the second attempt, add an action item and flag to notify responsibles
        doNotify      = true;
        actionItems   = animal.actItems;
        actionItems{end+1}  = sprintf('Weight too low (%.4gg) on %s.', data.weight, datestr(now, AnimalDatabase.DATE_DISPLAY));
        animal        = obj.pushAnimalInfo(researcherID, animalID, 'actItems', actionItems);
      end
      
      
      %% Upload all editable entries and notify responsibles if necessary
      [logs, animal]  = obj.pushDailyInfo(researcherID, animalID, data);
      if doNotify
        if veryLowWeight
          notifyVeryLowWeight(animal,obj);
        else
          notifyLowWeight(animal,obj);
        end
      end
      
      %% Show the next animal in line
      obj.checkUpdateTimer([], [], true);
      if readEScale     % if controlled by electronic scale, wait for animal to be taken off
        set( hObject, 'String', 'Weigh', 'ForegroundColor', [0 0 0] );
        set( get(hObject,'Parent'), 'Widths', [-1, 5*AnimalDatabase.GUI_BTNSIZE] );
        editable        = ctrlLog( strcmpi(get(ctrlLog,'Enable'), 'on') );
        editable( strcmpi(get(editable,'Style'), 'text') ) = [];
        set(editable, 'Background', [1 1 1]);
      else
        obj.nextInLine(hObject, event, researcherID);
      end
      obj.okImDone(alreadyBusy);
      
    end
    
    
    %----- Layout for cage check in/out by a particular person
    function layoutCheckoutGUI(obj, personID, forFinalize)
      
      %% Get list of researchers and their animals for whom the current person is responsible for
      [primary,secondary]             = obj.whatShouldIDo(personID);
      responsibility                  = [primary, secondary];
      
      % Always filter out dead animals
      animals                         = obj.pullAnimalList({responsibility.ID});
      doCare                          = cell(size(animals));
      techDuty                        = cell(size(animals));
      for iID = 1:numel(responsibility)
        inEffect                      = obj.whatIsThePlan(animals{iID});
        animals{iID}( [inEffect.status] >= HandlingStatus.Dead )    ...
                                      = [];
        [doCare{iID}, techDuty{iID}]  = obj.shouldICare(animals{iID}, personID, false, ~forFinalize);
        
        %% UGLY : for cage-level selections, ensure that animals follow the minimum care level of their cage mates
        [cageID,cageIndex]            = AnimalDatabase.getCages(animals{iID});
        for iCage = 1:numel(cageID)
          sel                         = cageIndex == iCage;
          if any(doCare{iID}(sel))
            doCare{iID}(sel)          = true;
          end
        end
      end
      
      %% Clear existing components 
      description                     = {['Responsibility of ' personID], 'Other cages'};
      obj.cio.groups                  = gobjects(0);
      obj.btn.aniGroup                = gobjects(0);
      obj.cio.groupScroll             = gobjects(size(description));
      obj.cio.researcher              = gobjects(size(description));
      delete(get(obj.cio.filter, 'Children'));
      
      if isempty(responsibility)
        return;
      end
      
      %% Loop through animal filter settings
      showFirst                       = [];
      for iFilter = 1:numel(description)
        obj.cio.groupScroll(iFilter)  = uix.ScrollingPanel( 'Parent', obj.cio.filter );
        obj.cio.researcher(iFilter)   = uix.VBox( 'Parent', obj.cio.groupScroll(iFilter), 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_SEL_BKG );
        
        %% Apply animal selection according to the filter setting
        filterSel                     = cellfun(@(x) x == (numel(description)-iFilter), doCare, 'UniformOutput', false);
        selAnimals                    = cellfun(@(x,y) x(y), animals , filterSel, 'UniformOutput', false);
        selDuties                     = cellfun(@(x,y) x(y), techDuty, filterSel, 'UniformOutput', false);
        btnGroup                      = obj.showCheckoutList(obj.cio.researcher(iFilter), personID, responsibility, selAnimals, selDuties, forFinalize);

        %% Format all buttons
        set( obj.cio.filter, 'Selection', iFilter );
        drawnow;
        for iBtn = 1:numel(btnGroup)
          jObject                     = findjobj(btnGroup(iBtn));
          set(btnGroup(iBtn), 'UserData', [get(btnGroup(iBtn),'UserData'), {jObject, iFilter == 1}]);
        end
        AnimalDatabase.setBorderByState(btnGroup);
        
        if isempty(showFirst) && ~isempty(btnGroup)
          showFirst                   = iFilter;
        end
      end
     
      %% Setup callback functions to enable check in/out
      if isempty(showFirst)
        showFirst                     = 1;
      end
      set( obj.cio.filter  , 'TabTitles', description, 'Selection', showFirst );
      set( obj.btn.transfer, 'UserData', personID );
      set( obj.btn.signOff , 'Callback', {@obj.closeCheckoutGUI, personID, forFinalize} );

    end

    %----- Shows a single panel of cages for check in/out
    function allButtons = showCheckoutList(obj, hParent, personID, responsibility, animals, techDuty, forFinalize)
      
      %% Create a panel of cages per researcher
      groupHeight           = 2*AnimalDatabase.GUI_BTNSIZE;
      groupWidth            = 7*AnimalDatabase.GUI_BTNSIZE;
      resHeights            = [];
      maxWidth              = 0;
      numCurrent            = numel(obj.btn.aniGroup);
      
      for iRes = 1:numel(responsibility)
        %% Create panel and grid for buttons
        resHeights(end+1)   = AnimalDatabase.GUI_BTNSIZE;
        cntResearcher       = uix.Panel ( 'Parent'              , hParent                           ...
                                        , 'Title'               , sprintf('%s (%s)', responsibility(iRes).Name, responsibility(iRes).ID)  ...
                                        , 'FontSize'            , AnimalDatabase.GUI_FONT           ...
                                        , 'BackgroundColor'     , AnimalDatabase.CLR_SEL_BKG        ...
                                        );
        obj.cio.groups(end+1)   ...
                            = uix.Grid  ( 'Parent'              , cntResearcher                     ...
                                        , 'Spacing'             , AnimalDatabase.GUI_BORDER         ...
                                        , 'Padding'             , 2*AnimalDatabase.GUI_BORDER       ...
                                        , 'BackgroundColor'     , AnimalDatabase.CLR_SEL_BKG        ...
                                        );
        if isempty(animals{iRes})
          continue;
        end
        
        %% Create one button per cage with associated animals listed
        [cageID,cageIndex]  = AnimalDatabase.getCages(animals{iRes});
        techTrains          = false(size(cageID));
        btnGroup            = gobjects(size(cageID));
        for iGrp = 1:numel(cageID)
          %% Format cage contents display
          groupAni          = animals{iRes}(cageIndex == iGrp);
          info              = cageID{iGrp};
          techDoes          = techDuty{iRes}(cageIndex == iGrp);
          if any( techDoes == Responsibility.Train )
            techTrains(iGrp)= true;
            info            = ['<font color="blue"><b>' info '</b></font>'];
          end
          info              = { sprintf('%s&nbsp;&nbsp;<font color="gray">(&times;%d)</font>', info, numel(groupAni)) };
          info{end+1}       = ['<div style="font-size:97%; color=inherit">' strjoin({groupAni.ID},', ') '</div>'];
          info              = strjoin(info,'');

          %% Background color depends on where the cage is at right now
          [location, description, inEffect]      ...
                            = obj.whereIsThisThing(groupAni, personID);
          bkgColor          = LocationState.color(location);
          if location == LocationState.WithYou
            bkgColor        = get(obj.btn.responsible, 'Background');
          elseif location == LocationState.AtHome && all(ismember([inEffect.status], HandlingStatus.AdLibWater))
            bkgColor        = bkgColor * 0.8;
            description     = [description ' (ad-lib watering)'];
          end
          
          techDoes          = arrayfun(@char, unique(techDoes), 'UniformOutput', false);
          description       = [strjoin(techDoes,' / '), ' : ', description];
          

          %% Setup selection button, disabling check in/out from vivarium unless the user is at the vivarium
          btnGroup(iGrp)    = uicontrol ( 'Parent'              , obj.cio.groups(end)                   ...
                                        , 'Style'               , 'togglebutton'                        ...
                                        , 'String'              , ['<html><div style="text-align:center">' info '</div></html>']  ...
                                        , 'FontSize'            , AnimalDatabase.GUI_FONT               ...
                                        , 'BackgroundColor'     , bkgColor                              ...
                                        , 'UserData'            , {location, groupAni}                  ...
                                        , 'Callback'            , {@obj.selectAnimalGroup, personID, forFinalize}                     ...
                                        , 'TooltipString'       , ['<html><div style="font-size:14px">' description '</div></html>']  ...
                                        , 'Interruptible'       , 'off'                                 ...
                                        , 'BusyAction'          , 'cancel'                              ...
                                        );
          obj.btn.aniGroup(end+1) = btnGroup(iGrp);
        end

        %% Rearrange buttons so that all tech-trained cages come first
        [nRows,nCols]       = AnimalDatabase.layoutButtonGrid(obj.cio.groups(end), groupWidth, false);
        resHeights(end)     = resHeights(end) + nRows*groupHeight;
        btnGroup            = [btnGroup(techTrains); btnGroup(~techTrains)];
        set(obj.cio.groups(end), 'Children', flip(btnGroup));
      end
      
      %% Layout contents and scrolling limits
      allButtons            = obj.btn.aniGroup(numCurrent + 1:end);
      set(hParent, 'Heights', resHeights);
      set(get(hParent,'Parent'), 'MinimumHeight', sum(resHeights) + (1 + numel(resHeights))*AnimalDatabase.GUI_BORDER, 'MinimumWidth', maxWidth);
      
    end
    
    %----- Starts a GUI for animal check in/out by a particular person
    function checkoutGUI(obj, hObject, event, personID, forFinalize)
      
      if nargin < 5
        forFinalize           = false;
      end
      alreadyBusy             = obj.waitImWorking();
      
      %% Create figure to populate
      if ishghandle(obj.figCheckout)
        delete(obj.figCheckout);
      end
      obj.figCheckout         = makePositionedFigure( AnimalDatabase.GUI_POSITION                     ...
                                                    , AnimalDatabase.GUI_MONITOR                      ...
                                                    , 'OuterPosition'                                 ...
                                                    , 'Name'            , [AnimalDatabase.GUI_TITLE ' Check In/Out']      ...
                                                    , 'ToolBar'         , 'none'                      ...
                                                    , 'MenuBar'         , 'none'                      ...
                                                    , 'NumberTitle'     , 'off'                       ...
                                                    , 'Visible'         , 'off'                       ...
                                                    , 'Tag'             , 'persist'                   ...
                                                    , 'WindowStyle'     , 'normal'                    ...
                                                    , 'CloseRequestFcn' , {@obj.closeCheckoutGUI, personID, forFinalize}  ...
                                                    );
      set(obj.figCheckout, 'Pointer', 'watch', 'UserData', personID);
      drawnow;
      
      %% Define main controls and data display regions
      obj.cio.main            = uix.VBox( 'Parent', obj.figCheckout, 'Spacing', AnimalDatabase.GUI_BORDER, 'Padding', 2*AnimalDatabase.GUI_BORDER, 'BackgroundColor', [1 1 1] );
      obj.cio.controls        = uix.HBox( 'Parent', obj.cio.main, 'Spacing', AnimalDatabase.GUI_BTNSIZE, 'BackgroundColor', [1 1 1] );
      obj.cio.filter          = uix.TabPanel( 'Parent', obj.cio.main, 'FontSize', AnimalDatabase.GUI_FONT, 'TabWidth', 10*AnimalDatabase.GUI_BTNSIZE  ...
                                            , 'Padding', 2*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_SEL_BKG );
      
      %% Define action buttons
                                uix.Empty ( 'Parent', obj.cio.controls );
      obj.btn.cageMissing     = uicontrol ( 'Parent'         , obj.cio.controls                       ...
                                          , 'Style'         , 'pushbutton'                            ...
                                          , 'String'        , 'FLAG missing'                          ...
                                          , 'TooltipString' , '<html><div style="font-size:14px">Flag entire cage as missing</div></html>'            ...
                                          , 'FontSize'      , AnimalDatabase.GUI_FONT                 ...
                                          , 'Visible'       , 'off'                                   ...
                                          , 'Interruptible' , 'off'                                   ...
                                          , 'BusyAction'    , 'cancel'                                ...
                                          );
                                uix.Empty ( 'Parent', obj.cio.controls );
      obj.btn.transfer        = uicontrol ( 'Parent'         , obj.cio.controls                       ...
                                          , 'Style'         , 'pushbutton'                            ...
                                          , 'String'        , 'Check In/Out'                          ...
                                          , 'TooltipString' , '<html><div style="font-size:14px">Check in/out selected cages</div></html>'            ...
                                          , 'FontSize'      , AnimalDatabase.GUI_FONT                 ...
                                          , 'Enable'        , 'off'                                   ...
                                          , 'Interruptible' , 'off'                                   ...
                                          , 'BusyAction'    , 'cancel'                                ...
                                          );
      obj.btn.allCheckout     = uicontrol ( 'Parent'         , obj.cio.controls                       ...
                                          , 'Style'         , 'pushbutton'                            ...
                                          , 'String'        , 'All check-outs'                        ...
                                          , 'TooltipString' , '<html><div style="font-size:14px">Select all cages that can be checked out (from the current tab only)</div></html>' ...
                                          , 'FontSize'      , AnimalDatabase.GUI_FONT                 ...
                                          , 'Callback'      , {@obj.selectAllGroups, personID, false} ...
                                          , 'Interruptible' , 'off'                                   ...
                                          , 'BusyAction'    , 'cancel'                                ...
                                          );
      obj.btn.allCheckin      = uicontrol ( 'Parent'         , obj.cio.controls                       ...
                                          , 'Style'         , 'pushbutton'                            ...
                                          , 'String'        , 'All check-ins'                         ...
                                          , 'TooltipString' , '<html><div style="font-size:14px">Select all cages that can be checked in (from the current tab only)</div></html>'  ...
                                          , 'FontSize'      , AnimalDatabase.GUI_FONT                 ...
                                          , 'Callback'      , {@obj.selectAllGroups, personID, true}  ...
                                          , 'Interruptible' , 'off'                                   ...
                                          , 'BusyAction'    , 'cancel'                                ...
                                          );
      obj.btn.clearCheck      = uicontrol ( 'Parent'         , obj.cio.controls                       ...
                                          , 'Style'         , 'pushbutton'                            ...
                                          , 'String'        , 'Clear selection'                       ...
                                          , 'TooltipString' , '<html><div style="font-size:14px">Clear currently selected selection</div></html>'     ...
                                          , 'FontSize'      , AnimalDatabase.GUI_FONT                 ...
                                          , 'Visible'       , 'off'                                   ...
                                          , 'Callback'      , {@obj.clearGroupSelection, personID, forFinalize}                                       ...
                                          , 'Interruptible' , 'off'                                   ...
                                          , 'BusyAction'    , 'cancel'                                ...
                                          );
      obj.btn.signOff         = uicontrol ( 'Parent'        , obj.cio.controls                        ...
                                          , 'Style'         , 'pushbutton'                            ...
                                          , 'String'        , 'FINALIZE'                              ...
                                          , 'TooltipString' , '<html><div style="font-size:14px">Signs you off for the day after checking for any remaining tasks</div></html>'  ...
                                          , 'FontSize'      , AnimalDatabase.GUI_FONT                 ...
                                          , 'Enable'        , 'off'                                   ...
                                          , 'Interruptible' , 'off'                                   ...
                                          , 'BusyAction'    , 'cancel'                                ...
                                          );
                                uix.Empty( 'Parent', obj.cio.controls );
      
      %% Configure layout proportions
      set(obj.cio.main    , 'Heights', [1.2*AnimalDatabase.GUI_BTNSIZE, -1]);
      set(obj.cio.controls, 'Widths', [-1, 6*AnimalDatabase.GUI_BTNSIZE, 3*AnimalDatabase.GUI_BTNSIZE, 6*AnimalDatabase.GUI_BTNSIZE, 4*AnimalDatabase.GUI_BTNSIZE   ...
                                      , 4*AnimalDatabase.GUI_BTNSIZE, 5*AnimalDatabase.GUI_BTNSIZE, 10*AnimalDatabase.GUI_BTNSIZE, -1]);
      
      %% This fills the panels etc.
      obj.layoutCheckoutGUI(personID, forFinalize);
      
      %% Restore non-busy cursor and wait for user to close checkout window
      set( obj.figCheckout, 'Pointer', 'arrow', 'Visible', 'on' );
      set( obj.cio.filter, 'SelectionChangedFcn', {@obj.selectAnimalGroup, personID, forFinalize} );
      executeCallback(obj.cio.filter, 'SelectionChangedFcn');
      obj.okImDone(alreadyBusy);
      
    end

    %----- Callback to select cages to check in/out; enforces consistency of selection
    function selectAnimalGroup(obj, hObject, event, personID, forFinalize)

      %% Indicate using a button border whether user has selected or deselected this group
      if ~isempty(hObject) && strcmpi(get(hObject,'Type'), 'uicontainer')
        hObject     = [];
      elseif isempty(hObject)
        set(obj.btn.aniGroup, 'Value', 0);
      end
      AnimalDatabase.setBorderByState(obj.btn.aniGroup);
      
      %% Require that all selected cages are either for check in or for check out
      currentTab    = 2 - get(obj.cio.filter, 'Selection');
      inYourCare    = arrayfun(@(x) get(x,'UserData'), obj.btn.aniGroup, 'UniformOutput', false);
      inYourCare    = cellfun(@(x) x{4}, inYourCare);
      selected      = arrayfun(@(x) get(x,'Value')==1, obj.btn.aniGroup);
      location      = cellfun(@(x) x{1}, get(obj.btn.aniGroup, 'UserData'), 'UniformOutput', false);
      location      = [location{:}];
      forCheckIn    = ( location == LocationState.WithYou );
      switch sum(selected)
        case 0
          %% If nothing is selected, allow selection of all cages (if in vivarium)
          set(obj.btn.aniGroup, 'Enable', 'on');
          if forFinalize
            set(obj.btn.aniGroup(location ~= LocationState.WithYou), 'Enable', 'off');
          end
          if ~strcmpi(obj.whoAmI, AnimalDatabase.ANI_HOME)
            set(obj.btn.aniGroup(location == LocationState.AtHome), 'Enable', 'off');
          end
          
          set( obj.btn.transfer, 'String', 'Select cage(s)', 'Enable', 'off' );
          set( obj.btn.clearCheck, 'Visible', 'off' );
          set( obj.btn.cageMissing, 'Visible', 'off' );
            
        case 1
          %% If this is the first selection, restrict to either check in or check out
          disallow  = ( forCheckIn ~= forCheckIn(selected) );

          set( obj.btn.aniGroup(disallow), 'Enable', 'off' );
          set( obj.btn.clearCheck, 'Visible', 'on' );
          set( obj.btn.cageMissing, 'String', 'FLAG missing', 'Visible', 'on', 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED  ...
             , 'Callback', {@obj.entireCageLost, personID, true}, 'ForegroundColor', [0 0 0], 'FontWeight', 'normal'              ...
             );
          
        otherwise
          set( obj.btn.clearCheck, 'Visible', 'on' );
      end
      
      %% Flag whether or not we can do bulk check-ins/outs
      canManipulate = strcmpi( get(obj.btn.aniGroup,'Enable'), 'on' )  & ( inYourCare(:) == currentTab );
      set( [obj.btn.allCheckout, obj.btn.allCheckin], 'Enable', 'on' );
      if ~any(forCheckIn(canManipulate))
        set( obj.btn.allCheckin , 'Enable', 'off'  );
      end
      if ~any(~forCheckIn(canManipulate))
        set( obj.btn.allCheckout, 'Enable', 'off'  );
      end
      
      %% Allow finalization only when all cages on the user's responsibility list are checked in
      if      any(location == LocationState.WithYou)                ...
          ||  ( forFinalize && any(location(inYourCare) ~= LocationState.AtHome) )
        set( obj.btn.signOff, 'Enable', 'off' );
      else
        set( obj.btn.signOff, 'Enable', 'on' );
      end
      
      if isempty(hObject)
        return;
      end
      
      %% Set the action button state and callback for either check in or check out
      forCheckIn    = unique( location(selected) == LocationState.WithYou );
      if sum(selected) == 1
        plural      = '';
      else
        plural      = 's';
      end
      if isempty(forCheckIn)
        set( obj.btn.transfer, 'String', 'Select cage(s)', 'Enable', 'off' );
      elseif numel(forCheckIn) > 1
        error('AnimalDatabase:selectAnimalGroup', 'Inconsistent cage check in/out state.');
      elseif forCheckIn
        set (  obj.btn.transfer, 'String', sprintf('Check in %d cage%s',sum(selected),plural), 'Enable', 'on'               ...
            , 'Callback', {@obj.transferAnimals, AnimalDatabase.ANI_HOME, [], personID, forFinalize}                        ...
            );
      else
        set ( obj.btn.transfer, 'String', sprintf('Check out %d cage%s',sum(selected),plural), 'Enable', 'on'               ...
            , 'Callback', {@obj.transferAnimals, get(obj.btn.transfer,'UserData'), obj.figCheckout, personID, forFinalize}  ...
            );
      end
      
    end
    
    %----- Callback to clear all currently selected check in/out cages
    function clearGroupSelection(obj, hObject, event, personID, forFinalize)
      set(obj.btn.aniGroup, 'Value', 0);

      for iGrp = 1:numel(obj.btn.aniGroup)
        info        = get(obj.btn.aniGroup(iGrp), 'UserData');
        jObject     = info{3};
        jObject.setBorder(javax.swing.border.LineBorder(java.awt.Color.lightGray, 1, false));
      end
      
      obj.selectAnimalGroup([], [], personID, forFinalize);
    end
    
    %----- Transfer the location of selected cages to the given holder
    function transferAnimals(obj, hObject, event, holderID, closeFig, personID, forFinalize)
      %% Loop through all selected groups of animals
      btnGroup        = obj.btn.aniGroup(arrayfun(@(x) get(x,'Value'), obj.btn.aniGroup) == 1);
      for iGrp = 1:numel(btnGroup)
        info          = get(btnGroup(iGrp), 'UserData');
        groupAni      = info{2};
        
        %% Push the new location of these animals 
        researcherID  = unique({groupAni.owner});
        if numel(researcherID) ~= 1
          error('AnimalDatabase:transferAnimals', 'Invalid researcher (owner) ID for animals: %s', strjoin({groupAni.ID}));
        end
        obj.pushBatchInfo(researcherID{:}, {groupAni.ID}, 'whereAmI', holderID);
        
        %% Record the new location for further interactions with the GUI
        [groupAni.whereAmI] = deal(holderID);
        info{1}             = obj.whereIsThisThing(groupAni, personID);
        info{2}             = groupAni;
        set(btnGroup(iGrp), 'UserData', info);
      end
      
      %% Close the GUI figure if so desired
      if isempty(closeFig)
        obj.selectAnimalGroup([], [], personID, forFinalize);
      else
        delete(closeFig);
        if strcmpi(get(obj.axs.aniImage,'Visible'), 'off')
          delete( get(obj.tbl.aniData, 'Children') );
          delete( get(obj.tbl.aniDaily, 'Children') );
        end
      end
    end
    
    %----- Transfer the location of selected cages to the given holder
    function selectAllGroups(obj, hObject, event, personID, forCheckIn)
      
      %% Select all cages for either check in or check out
      location      = arrayfun(@(x) get(x,'UserData'), obj.btn.aniGroup, 'UniformOutput', false);
      location      = cellfun(@(x) x{1}, location, 'UniformOutput', false);
      location      = [location{:}];
      checkIn       = ( location == LocationState.WithYou );
      currentTab    = 2 - get(obj.cio.filter, 'Selection');
      aniGroup      = obj.btn.aniGroup(checkIn == forCheckIn);
      
      %% Restrict to cages on current tab, and those that are selectable only
      aniGroup( ~strcmpi(get(aniGroup,'Enable'), 'on') )      = [];
      inYourCare    = arrayfun(@(x) get(x,'UserData'), aniGroup, 'UniformOutput', false);
      inYourCare    = cellfun(@(x) x{4}, inYourCare);
      aniGroup( inYourCare ~= currentTab )                    = [];
      aniGroup( arrayfun(@(x) get(x,'Value')==1, aniGroup) )  = [];
      
      %% Apply selection and update GUI
      if isempty(aniGroup)
        return;
      end
      set( aniGroup, 'Value', 1 );
      executeCallback(aniGroup(end));
      
    end
    
    %----- Transfer the location of selected cages to the given id
    function entireCageLost(obj, hObject, event, personID, requireConfirm)
      %% Require a second button press if so desired
      if requireConfirm
        set( hObject, 'String', 'CONFIRM missing', 'Visible', 'on', 'BackgroundColor', [1 1 1]*0.4, 'FontWeight', 'bold'          ...
           , 'Callback', {@obj.entireCageLost, personID, false}, 'ForegroundColor', HandlingStatus.color(HandlingStatus.Missing)  ...
           );
        return;
      end
      
      %% Loop through all selected groups of animals
      btnGroup        = obj.btn.aniGroup(arrayfun(@(x) get(x,'Value'), obj.btn.aniGroup) == 1);
      for iGrp = 1:numel(btnGroup)
        groupAni      = get(btnGroup(iGrp), 'UserData');
        groupAni      = groupAni{2};
        researcherID  = unique({groupAni.owner});
        if numel(researcherID) ~= 1
          error('AnimalDatabase:transferAnimals', 'Invalid researcher (owner) ID for animals: %s', strjoin({groupAni.ID}));
        end
        
        obj.somethingHappened(hObject, event, researcherID{:}, groupAni, HandlingStatus.Missing, gobjects(0));
      end
      
      %% Recreate GUI displays due to these major changes
      
    end
    
    
    %----- (Re-)create GUI figure and layout for performance summary
    function performanceGUI(obj)

      %% Create figure to populate
      obj.closePerformanceGUI();
      obj.figPerform          = makePositionedFigure( AnimalDatabase.GUI_POSITION                     ...
                                                    , AnimalDatabase.GUI_MONITOR                      ...
                                                    , 'OuterPosition'                                 ...
                                                    , 'Name'            , [AnimalDatabase.GUI_TITLE ' Performance'] ...
                                                    , 'ToolBar'         , 'none'                      ...
                                                    , 'MenuBar'         , 'none'                      ...
                                                    , 'NumberTitle'     , 'off'                       ...
                                                    , 'Visible'         , 'on'                       ...
                                                    , 'Tag'             , 'persist'                   ...
                                                    , 'CloseRequestFcn' , @obj.closePerformanceGUI    ...
                                                    );
      
      %% Define main controls and data display regions
      obj.pfm.main            = uix.VBox( 'Parent', obj.figGUI, 'Spacing', 5*AnimalDatabase.GUI_BORDER, 'Padding', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.config          = uix.HBox( 'Parent', obj.cnt.main, 'Spacing', AnimalDatabase.GUI_BORDER, 'Padding', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.data            = uix.HBoxFlex( 'Parent', obj.cnt.main, 'Spacing', 3*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      % Top bar: selector for responsible, action buttons
      obj.cnt.person          = uix.HBox( 'Parent', obj.cnt.config, 'Spacing', 2*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.controls        = uix.HBox( 'Parent', obj.cnt.config, 'Spacing', 2*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      % Responsible selector
      obj.btn.responsible     = uicontrol( 'Parent', obj.cnt.person, 'Style', 'pushbutton', 'String', 'Responsible'                                                 ...
                                         , 'TooltipString', '<html><div style="font-size:14px">View/edit person info</div></html>'                                  ...
                                         , 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      obj.lst.responsible     = uicontrol( 'Parent', obj.cnt.person, 'Style', 'popupmenu', 'String', {'( select yourself )'}, 'FontSize', AnimalDatabase.GUI_FONT   ...
                                         , 'Callback', @obj.showResponsible, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      
      % Things to do
                                uix.Empty( 'Parent', obj.cnt.controls );
      obj.axs.scaleRead       = axes( 'Parent', obj.cnt.controls, 'XLim', [1 100], 'YLim', [0 50], 'Box', 'on', 'ActivePositionProperty', 'Position'                ...
                                    , 'XColor', [1 1 1]*0.7, 'YColor', [1 1 1]*0.7, 'XTick', [], 'YTick', [], 'Visible', 'off', 'Clipping', 'off' );
      obj.btn.weighMode       = uicontrol( 'Parent', obj.cnt.controls, 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel', 'UserData', 0 );
                                uix.Empty( 'Parent', obj.cnt.controls );
      obj.btn.checkInOut      = uicontrol( 'Parent', obj.cnt.controls, 'Style', 'pushbutton', 'String', 'Check In/Out'                                              ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Selection screen to check in/out cages</div></html>'                 ...
                                         , 'FontSize', AnimalDatabase.GUI_FONT, 'Enable', 'off', 'Interruptible', 'off', 'BusyAction', 'cancel' );
      obj.btn.finalize        = uicontrol( 'Parent', obj.cnt.controls, 'Style', 'pushbutton', 'String', 'FINALIZE'                                                  ...
                                         , 'TooltipString', '<html><div style="font-size:14px">Check that all animals you''re responsible for have been handled</div></html>'                       ...
                                         , 'FontSize', AnimalDatabase.GUI_FONT, 'Interruptible', 'off', 'BusyAction', 'cancel' );
      obj.setScaleState();

      %% Define live data display
      obj.cnt.overview        = uix.VBox( 'Parent', obj.cnt.data, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.details         = uix.VBoxFlex( 'Parent', obj.cnt.data, 'Spacing', 3*AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      obj.cnt.researcher      = uix.HButtonBox( 'Parent', obj.cnt.overview, 'Spacing', AnimalDatabase.GUI_BORDER, 'ButtonSize', [5 2]*AnimalDatabase.GUI_BTNSIZE, 'HorizontalAlignment', 'left', 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.groupScroll     = uix.ScrollingPanel( 'Parent', obj.cnt.overview );
      obj.cnt.aniGroups       = uix.VBox( 'Parent', obj.cnt.groupScroll, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      
      %% Define animal details display
      obj.cnt.aniInfo         = uix.HBox( 'Parent', obj.cnt.details, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.dailyScroll     = uix.ScrollingPanel( 'Parent', obj.cnt.details );
      obj.tbl.aniDaily        = uix.Grid( 'Parent', obj.cnt.dailyScroll, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );

      cntAni                  = uix.VBox( 'Parent', obj.cnt.aniInfo, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.tbl.aniID           = uix.Grid( 'Parent', cntAni, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.axs.aniImage        = Canvas( AnimalDatabase.ANI_IMAGE_SIZE, cntAni, true, [1 1 1], 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );
      obj.cnt.dataScroll      = uix.ScrollingPanel( 'Parent', obj.cnt.aniInfo );
      obj.tbl.aniData         = uix.Grid( 'Parent', obj.cnt.dataScroll, 'Spacing', AnimalDatabase.GUI_BORDER, 'BackgroundColor', AnimalDatabase.CLR_GUI_BKG );

      
      %% Configure layout proportions
      elemSize                = AnimalDatabase.GUI_BTNSIZE + AnimalDatabase.GUI_BORDER;
      aniIDHeight             = (1 + numel(AnimalDatabase.ANI_ID_INFO)) * elemSize;
      
      set(obj.cnt.main      , 'Heights', [1.2*AnimalDatabase.GUI_BTNSIZE + 2*AnimalDatabase.GUI_BORDER, -1]);
      set(obj.cnt.config    , 'Widths' , [10*AnimalDatabase.GUI_BTNSIZE, -1]);
      set(obj.cnt.person    , 'Widths' , [4*AnimalDatabase.GUI_BTNSIZE, -1]);
      set(obj.cnt.controls  , 'Widths' , [AnimalDatabase.GUI_BTNSIZE, -1, 7*AnimalDatabase.GUI_BTNSIZE, AnimalDatabase.GUI_BTNSIZE, 4*AnimalDatabase.GUI_BTNSIZE, 9.5*AnimalDatabase.GUI_BTNSIZE]);
      set(obj.cnt.data      , 'Widths' , [3*(1 + AnimalDatabase.MAX_ANI_GROUP)*elemSize + 0.5*AnimalDatabase.GUI_BTNSIZE, -1]);
      set(obj.cnt.overview  , 'Heights', [2*AnimalDatabase.GUI_BTNSIZE, -1]);

      set(cntAni            , 'Heights', [aniIDHeight, -1]);
      set(obj.cnt.details   , 'Heights', [5*AnimalDatabase.ANI_IMAGE_SIZE(1) + aniIDHeight, -1]);
      set(obj.cnt.aniInfo   , 'Widths' , [5*AnimalDatabase.ANI_IMAGE_SIZE(1) + Canvas.GUI_BTNSIZE, -1]);
      
      %% Default arguments
      if nargin < 2
        personID  = [];
      end
      
      %% Populate responsibles list
      obj.pullOverview();
      set ( obj.lst.responsible                                                     ...
          , 'String'        , {obj.Technicians.ID, obj.Researchers.ID}              ...
          );
        
      %% Select a particular responsible, if provided
      if ~isempty(personID)
        index  = find(strcmpi(get(obj.lst.responsible, 'String'), personID));
        if isempty(index)
          error('AnimalDatabase:layoutResponsibles', 'Person %s not found in the list of technicians/researchers.', personID);
        end
        set( obj.lst.responsible, 'Value', index );
      end
        
      obj.showResponsible([], [], false);
    end
    

    
    %----- Shows a list of cages and animals to be returned
    function showAnimalReturnList(obj, hParent, animals, description, showWhere, color)
      if nargin < 5 || isempty(showWhere)
        showWhere               = false;
      end
      if nargin < 6 || isempty(color)
        color                   = [0 0 0];
      end
      
      %% Compose list of animals organized by cages
      [cageName, cageIndex]     = AnimalDatabase.getCages(animals);
      message                   = cell(size(cageName));
      for iCage = 1:numel(cageName)
        cageAni                 = animals(cageIndex==iCage);
        info                    = {['<th><b>' cageName{iCage} '</b></th>']};
        if showWhere
          info{end+1}           = ['<td>(with ', strjoin(unique({cageAni.whereAmI}), ' & '), ')</td>'];
        end
        info{end+1}             = '<td>:</td>';
        info                    = [info, {'<td>', strjoin({cageAni.ID}, ', '), '</td>'}];
        message{iCage}          = ['<tr>' strjoin(info,' ') '</tr>'];
      end
      message                   = ['<table cellspacing="10">' strjoin(message,' ') '</table>'];
      message                   = ['<div style="font-size:110%; text-align:left">' description '</div>' message];
      
      %% Create display control
      btnMessage                = uicontrol ( 'Parent'                  , hParent                             ...
                                            , 'String'                  , ['<html>' message '</html>']        ...
                                            , 'Style'                   , 'togglebutton'                      ...
                                            , 'Enable'                  , 'inactive'                          ...
                                            , 'FontSize'                , AnimalDatabase.GUI_FONT             ...
                                            , 'BackgroundColor'         , AnimalDatabase.CLR_GUI_BKG          ...
                                            , 'ForegroundColor'         , color                               ...
                                            , 'Interruptible'           , 'off'                               ...
                                            , 'BusyAction'              , 'cancel'                            ...
                                            );
      jObject                   = AnimalDatabase.setBorderByState(btnMessage);
      jObject.setVerticalAlignment(javax.swing.JLabel.TOP);
    end
    
    %----- Triggers the next thing to be done, or finalize the day
    function allDone = areWeThereYet(obj, hObject, event, personID, allowCheckin)
      
      if nargin < 5
        allowCheckin            = true;
      end
      
      %% Try to go to the next animal in line
      theShowMustGoOn           = obj.nextInLine();
      if theShowMustGoOn
        return;
      end
      alreadyBusy               = obj.waitImWorking();
      

      %% Get the list of all animals and detect which ones have been checked out by you
      [primary,secondary]       = obj.whatShouldIDo(personID);
      animals                   = obj.pullAnimalList({primary.ID, secondary.ID});
      [doCare,~,animals]        = obj.shouldICare([animals{:}], personID);
      % Can't do much with dead/missing animals
      lostSouls                 = animals([animals.status] == HandlingStatus.Missing);
      noHope                    = ismember([animals.status], AnimalDatabase.EMERGENCY_STATUS);
      doCare(noHope)            = [];
      animals(noHope)           = [];
      checkedOutByYou           = strcmpi({animals.whereAmI}, personID);
      outOnYourWatch            = doCare & ~checkedOutByYou & ~strcmpi({animals.whereAmI}, AnimalDatabase.ANI_HOME);
      
      %% Print a status message depending on whether there's stuff left to do
      if ~any(checkedOutByYou) && ~any(outOnYourWatch)
        message                 = 'All done!';
        color                   = AnimalDatabase.CLR_ALLSWELL;
        allDone                 = true;
      elseif strcmpi(obj.whoAmI, AnimalDatabase.ANI_HOME)
        message                 = 'You still need to check in animals.';
        color                   = AnimalDatabase.CLR_SELECT;
        allDone                 = false;
        goHome                  = false;
      else
        message                 = ['You need to use the computer in the ' AnimalDatabase.ANI_HOME ' to check in animals.'];
        color                   = AnimalDatabase.CLR_ALERT;
        allDone                 = false;
        goHome                  = true;
      end
      message                   = sprintf('<div style="color:rgb(%d,%d,%d)">%s</div>', color(1)*255, color(2)*255, color(3)*255, message);
      if ~isempty(lostSouls)
        color                   = AnimalDatabase.CLR_ALERT;
        imLost                  = sprintf('%d animal(s) are MISSING: %s', numel(lostSouls), strjoin({lostSouls.ID},', '));
        message                 = sprintf('<div style="color:rgb(%d,%d,%d)">%s</div> %s', color(1)*255, color(2)*255, color(3)*255, imLost, message);
      end
      
      delete( get(obj.tbl.aniData, 'Children') );
      btnMessage                = uicontrol ( 'Parent'                  , obj.tbl.aniData                     ...
                                            , 'String'                  , ['<html>' message '</html>']        ...
                                            , 'Style'                   , 'togglebutton'                      ...
                                            , 'Enable'                  , 'inactive'                          ...
                                            , 'FontSize'                , AnimalDatabase.GUI_FONT * 1.5       ...
                                            , 'FontWeight'              , 'bold'                              ...
                                            , 'BackgroundColor'         , AnimalDatabase.CLR_GUI_BKG          ...
                                            , 'Interruptible'           , 'off'                               ...
                                            , 'BusyAction'              , 'cancel'                            ...
                                            );
      AnimalDatabase.setBorderByState(btnMessage);
      
      %% Print the list of animals that need to be returned
      delete( get(obj.tbl.aniDaily, 'Children') );
      if allDone
        axsCandy                = axes( 'Parent'            , obj.tbl.aniDaily                ...
                                      , 'Color'             , 'none'                          ...
                                      , 'XColor'            , 'none'                          ...
                                      , 'YColor'            , 'none'                          ...
                                      );
        imgCandy                = image('Parent', axsCandy, 'CData', AnimalDatabase.IMAGE_CANDY, 'CDataMapping', 'direct');
        axis(axsCandy, 'image', 'ij');
      end
      if any(checkedOutByYou)
        obj.showAnimalReturnList(obj.tbl.aniDaily, animals(checkedOutByYou), 'These are currently with you:');
      end
      if any(outOnYourWatch)
        obj.showAnimalReturnList(obj.tbl.aniDaily, animals(outOnYourWatch), 'You need to track these down:', true, AnimalDatabase.CLR_ALERT);
      end
      
      
      %% If the user has checked out cages, they must be checked in only in the vivarium computer
      if allDone
        obj.doneForTheDay([], [], personID);
      elseif allowCheckin && any(checkedOutByYou) && strcmpi(obj.whoAmI, AnimalDatabase.ANI_HOME)
        obj.checkoutGUI([], [], personID, true);
      end
      obj.okImDone(alreadyBusy);
      
    end
    
    %----- Checks that all animals under the given person's responsibility have been weighed and checked in
    function doneForTheDay(obj, hObject, event, personID, closeFig)
      %% Set busy state of all figures
      if nargin > 4 && ~isempty(closeFig)
        delete(closeFig);
      end
      alreadyBusy = obj.waitImWorking();

      %% Final checks and notifications
      userInfo    = obj.findSomebody(personID);
      checkMouseWeighing(userInfo,obj);
      checkCageReturn(userInfo,obj);
      checkActionItems(userInfo,obj);
      
      %% Restore non-busy pointer
      obj.okImDone(alreadyBusy);
    end
    
  end

  %_________________________________________________________________________________________________
  methods
    
    %----- Create an instance that can then be used to interface with the database
    function obj = AnimalDatabase(interactive)
      if nargin < 1
        interactive   = true;
      end
      
      %% Required to retrieve tokens from Google
      if ~exist('google_tokens.mat', 'file')
        RunOnce(AnimalDatabase.CLIENT_ID, AnimalDatabase.CLIENT_SECRET);
      end
      
      cookieManager   = java.net.CookieManager([], java.net.CookiePolicy.ACCEPT_ALL);
      java.net.CookieHandler.setDefault(cookieManager);
      obj.httpHandler = sun.net.www.protocol.https.Handler;
      
      %% Set self identification
      if exist('RigParameters', 'class')
        obj.whoAmI    = RigParameters.rig;
      else
        obj.whoAmI    = char(java.net.InetAddress.getLocalHost.getHostName);
      end
      
      %% Start background timers, try to start scale
      if interactive
        fprintf('Starting notification timers...\n');
        manageNotificationTimers('start',obj);

        fprintf('Attempting to connect to an electronic scale...\n');
        obj.connectToScale();

        fprintf('... ready now.\n');
      end
    end
    
    %----- destructor, for termination
    function delete(obj)
      manageNotificationTimers('stop',obj);
      if ~isempty(obj.eScale)
        delete(obj.eScale);
      end
      obj.closeGUI();
    end

    
    %----- Test all available serial ports to see if we can detect an OHAUS Scout scale
    function connectToScale(obj, hObject, event)
      alreadyBusy           = obj.waitImWorking();
      warnState             = warning('query','MATLAB:serial:fscanf:unsuccessfulRead');
      warning('off', warnState.identifier);
      
      %% Loop through all available serial ports
      serialPorts           = instrhwinfo('serial');
      serialPorts           = accumfun(2, @(x) x.SerialPorts, serialPorts);
      
      for iPort = 1:numel(serialPorts)
        %% Send a test message and see if there is an expected reply
        something           = auto_balance(serialPorts{iPort});
        if ~something.success
          continue
        end
        if something.verify_scale_connected(false)
          obj.eScale        = something;
          break
        end
      end

      %% Set flags and GUI state for whether the scale is connected
      warning(warnState.state, warnState.identifier);
      obj.setScaleState(serialPorts);
      obj.okImDone(alreadyBusy);
    end
    
    %----- Sets the scale to unavailable
    function disconnectScale(obj, hObject, event)

      obj.stopScaleTimer();
      if ~isempty(obj.eScale)
        delete(obj.eScale);
      end
      
      obj.eScale    = [];
      obj.setScaleState();
      
    end
    
    %----- if in weighing mode, start timer to poll scale at regular intervals
    function toggleScaleTimer(obj, hObject, event, oneShot, doTare)
      
      if isempty(obj.eScale) || ~obj.eScale.success
        return
      end
      if nargin < 4
        oneShot             = false;
      end
      if nargin < 5
        doTare              = false;
      end
      
      if get(obj.btn.weighMode, 'Value') == 0
        obj.stopScaleTimer();
        
      elseif ~oneShot && ~doTare && obj.eScale.pollWeight(1,inf)
        %% Scale has nonzero readout, prompt user to tare
        set(obj.btn.weighMode, 'String', 'CONFIRM Tare', 'Value', 0, 'ForegroundColor', AnimalDatabase.CLR_SELECT, 'Callback', {@obj.toggleScaleTimer,oneShot,true});
        
      else
        %% Tare scale if necessary
        if doTare
          if ~obj.eScale.tare()
            warning('AnimalDatabase:toggleScaleTimer', 'Could not tare scale, assuming that it has been disconnected.');
            beep;
            delete(obj.eScale);
            obj.eScale      = [];
            obj.setScaleState();
            return;
          end
          set(obj.btn.weighMode, 'String', 'Weighing Mode', 'ForegroundColor', [0 0 0], 'Callback', @obj.toggleScaleTimer);
        end
        if oneShot
          if obj.eScale.pollWeight(1,inf)       % if reading is already nonzero, assume that we've tared properly
            obj.eScale.setLastReadout(0);
          end
        end
        
        %% Create timer object to poll scale
        if ~isempty(obj.tmrPollScale) && isvalid(obj.tmrPollScale)
          stop(obj.tmrPollScale);
          delete(obj.tmrPollScale);
        end

        obj.tmrPollScale    = timer ( 'Name'                    , ['pollScale-' obj.whoAmI]           ...
                                    , 'BusyMode'                , 'drop'                              ...
                                    , 'ExecutionMode'           , 'fixedSpacing'                      ...
                                    , 'Period'                  , AnimalDatabase.UPDATE_PERIOD_SCALE  ...
                                    , 'TimerFcn'                , {@obj.pollScale, oneShot}           ...
                                    , 'StopFcn'                 , @obj.stopScaleTimer                 ...
                                    ); 
        
        %% Setup graphical indicators that we're now weighing
        set(obj.btn.weighMode, 'UserData', 0, 'BackgroundColor', get(obj.btn.responsible, 'BackgroundColor'));
        set(obj.axs.scaleRead, 'Visible', 'on', 'Color', AnimalDatabase.CLR_GUI_BKG);
        delete(get(obj.axs.scaleRead, 'Children'));

        xRange              = get(obj.axs.scaleRead, 'XLim');
        refX                = repmat([xRange(:); nan], 1, numel(auto_balance.VALID_WEIGHTS));
        refY                = repmat(auto_balance.VALID_WEIGHTS, 3, 1);
        line('Parent', obj.axs.scaleRead, 'XData', refX(:), 'YData', refY(:), 'LineWidth', 1, 'Color', [1 1 1]*0.8, 'LineStyle', '-.');
        obj.plt.minWeight   = text( xRange(1) + 0.05*diff(xRange), auto_balance.VALID_WEIGHTS(1), sprintf('%.3gg',auto_balance.VALID_WEIGHTS(1)), 'Parent', obj.axs.scaleRead, 'FontSize', 9    ...
                                  , 'Color', [1 1 1]*0.7, 'BackgroundColor', get(obj.axs.scaleRead,'Color'), 'HorizontalAlignment', 'left', 'VerticalAlignment', 'baseline'                     ...
                                  );

        nPoints             = xRange(end) - xRange(1) + 2;
        obj.plt.weight      = patch('Parent', obj.axs.scaleRead, 'XData', xRange(1):xRange(end)+1, 'YData', nan(1,nPoints), 'FaceVertexCData', zeros(nPoints,3), 'EdgeColor', 'flat', 'Clipping', 'off');
        obj.plt.lastRead    = line('Parent', obj.axs.scaleRead, 'XData', 0, 'YData', 0, 'LineWidth', 2, 'Marker', 'o', 'MarkerSize', 6, 'MarkerFaceColor', [0 0 0], 'MarkerEdgeColor', 'none', 'Clipping', 'off');
        obj.scaleReading    = nan;
        
        start(obj.tmrPollScale);
      end
      
    end
    
     %----- stop timer to poll scale at regular intervals
    function stopScaleTimer(obj,~,~)
      if ~isempty(obj.tmrPollScale) && isvalid(obj.tmrPollScale)
        stop(obj.tmrPollScale);
        delete(obj.tmrPollScale);
        
        obj.tmrPollScale      = [];
        obj.scaleReading      = nan;
      end
      
      if ishghandle(obj.btn.weighMode)
        set(obj.btn.weighMode, 'Value', 0, 'UserData', 0, 'String', 'Weighing Mode', 'FontWeight', 'normal', 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED);
        set(obj.axs.scaleRead, 'Visible', 'off');
        delete(get(obj.axs.scaleRead, 'Children'));
      end
    end
    
     %----- read from scale, if valid trigger weigh buttom
    function pollScale(obj, hObject, event, oneShot)
      
      try
    
      %% Read from scale and update circular buffer
      [weight,change,valid,isHigh]  = obj.eScale.pollWeight(AnimalDatabase.NUM_POLLS_SCALE, 5*AnimalDatabase.UPDATE_PERIOD_SCALE);
      yData                         = get(obj.plt.weight   , 'YData');
      nPoints                       = numel(yData) - 1;
      xReading                      = get(obj.plt.lastRead , 'XData');
      xReading                      = mod(xReading, nPoints) + 1;
      yData(xReading)               = weight;
      yData(xReading + 1)           = nan;
      
      % Color indicators for data validity and change detection
      if valid
        faceColor                   = AnimalDatabase.CLR_ALLSWELL;
      else
        faceColor                   = AnimalDatabase.CLR_ALERT;
      end
      if change
        edgeColor                   = AnimalDatabase.CLR_SELECT;
        markerSize                  = 9;
      else
        edgeColor                   = 'none';
        markerSize                  = 6;
      end
      
      set(obj.plt.weight  , 'YData', yData);
      set(obj.plt.lastRead, 'XData', xReading, 'YData', weight, 'MarkerFaceColor', faceColor, 'MarkerEdgeColor', edgeColor, 'MarkerSize', markerSize);

      
      %% If we're busy doing something else or no animal is selected, just store detected changes
      if change
        set(obj.btn.weighMode, 'UserData', change);
      else
        change                      = get(obj.btn.weighMode, 'UserData');
      end
      if valid && isHigh
        obj.scaleReading            = weight;
      else
        obj.scaleReading            = nan;
      end

      if obj.imBusy || ~isfield(obj.btn, 'aniInfo') || isempty(obj.btn.aniInfo) || ~any(arrayfun(@(x) get(x,'Value'), obj.btn.aniInfo))
        set(obj.axs.scaleRead, 'Color', AnimalDatabase.CLR_GUI_BKG);
        set(obj.plt.minWeight, 'BackgroundColor', get(obj.axs.scaleRead,'Color'));
        set(obj.btn.weighMode, 'String', 'Weighing Mode', 'FontWeight', 'normal');
        return;
      end

      %% Otherwise indicate that we're ready or taking data for the currently selected animal
      btnAni                        = obj.btn.aniInfo( arrayfun(@(x) get(x,'Value'), obj.btn.aniInfo) == 1 );
      info                          = get(btnAni, 'UserData');
      set(obj.btn.weighMode, 'String', ['Weighing ' info{1}], 'FontWeight', 'bold');
        
      switch change
        case {0, -1}
          set(obj.axs.scaleRead, 'Color', [1 1 1]);
        case  1
          set(obj.axs.scaleRead, 'Color', EntryState.color(EntryState.Suggested));
      end
      set(obj.plt.minWeight, 'BackgroundColor', get(obj.axs.scaleRead,'Color'));
      
      %% Trigger a weight recording if we're in a ready-to-accept state and there's a present or stored change
      if ~change || ~strcmpi(get(obj.btn.weighAni,'Enable'), 'on')
        return;
      end
      
      switch isHigh
        case false                                            % user took mouse off, go to next animal
          if strcmpi(get(obj.btn.weighMode,'Enable'), 'on')   % if re-weighing, don't advance animals
            if oneShot
              %% Special case to perform a one-time weighing of a mouse
              stop(obj.tmrPollScale);
              set(obj.tmrPollScale, 'TimerFcn', {@obj.pollScale, false});
            end

            btnWhose                = obj.btn.showWhose( arrayfun(@(x) get(x,'Value'), obj.btn.showWhose) == 1 );
            obj.nextInLine(hObject, event, get(btnWhose,'UserData'));
          end
          
        case true
          if ~isfinite(obj.scaleReading)
            error('AnimalDatabase:pollScale', 'Invalid recorded scale reading, should not be possible.');
          end
          executeCallback(obj.btn.weighAni, 'Callback', [], true);
      end
      set(obj.btn.weighMode, 'UserData', 0);                  % set that this change has been handled
      
      catch err
        %% Turn off weighing mode upon errors
        displayException(err);
        obj.disconnectScale();
%         set(obj.btn.weighMode, 'BackgroundColor', EntryState.color(EntryState.Invalid));
        beep;
      end
      
    end
    
    
    %----- Retrieve data from a given sheet of a Google document as a cell array of strings
    function [data, rawText] = readFromDatabase(obj, database, sheet, where, who)
      if nargin < 3 || isempty(sheet)
        sheet     = AnimalDatabase.FIRST_SHEET;
      end
      if nargin < 4 || isempty(where)
        where     = database;
      end
      if nargin < 5 || isempty(who)
        who       = '';
      end
      if ~isempty(who)
        who       = [' for ' who];
      end
      
      %% Get raw data as a cell array
      url         = sprintf( AnimalDatabase.EXPORT_FORMAT, AnimalDatabase.GOOGLESHEETS_URL, database, sheet );
      connection  = java.net.URL([], url, obj.httpHandler).openConnection(); % Constructs an URL object
      try
        rawText   = connection.getInputStream();
        rawText   = AnimalDatabase.readStream(rawText); % get content of website, specified by connection
      catch err
        error('AnimalDatabase:readFromDatabase', 'Invalid %s sheet ID "%s"%s.', where, sheet, who);
      end
      
      if isempty(rawText)
        data      = {};
        return;
      end
      
      %% Parse CSV into a cell array
      data        = csv2cell(rawText);

    end
    
    %----- Retrieve data from a given sheet of a Google document in a particular template-specified format
    function [info, nextRow] = parseFromDatabase(obj, template, row, database, sheet, where, who)
      if iscell(database)
        data            = database;
      else
        data            = obj.readFromDatabase(database, sheet, where, who);
      end
      if size(data,2) < numel(template)
        error('AnimalDatabase:parseFromDatabase', 'Too few columns (%d) in %s sheet ID "%s" for %s compared to the expected template (%d).', size(data,2), where, sheet, who, numel(template));
      end
      
      %% Initialize output with the fields in the given template
      info              = AnimalDatabase.emptyLike(template);
      fields            = {template.identifier};
      
      %% Add all available rows (stop when there is a completely empty one)
      nextRow           = row;
      while nextRow <= size(data,1)
        if all(cellfun(@isempty, data(nextRow,:)))
          break;
        end
        
        iData           = numel(info) + 1;
        for iCol = 1:numel(fields)
          info(iData).(fields{iCol})          ...
                        = obj.parseAsFormat(data{nextRow,iCol}, template(iCol).data);
        end
        nextRow         = nextRow  + 1;
      end
    end
    
    %----- Write a row into the database at the specified location
    function sheetID = writeDatabaseRow(obj, data, template, row, database, sheet, where, who)
      %% Convert data to string format
      dataRep           = cell(1, numel(template));
      for iField = 1:numel(template)
        dataRep{iField} = obj.applyFormat(data.(template(iField).identifier), template(iField).data);
      end
      
      %% Write at the given location
      try
        [~,sheetID]     = mat2sheets(database, sheet, [row,1], dataRep);
      catch err
        displayException(err);
        error('AnimalDatabase:writeDatabaseRow', 'Failed to write data into %s for %s.', where, who);
      end
    end
    
    %----- Write a column into the database at the specified location
    function sheetID = writeDatabaseCol(obj, data, template, col, database, sheet, where, who)
      %% Convert data to string format
      dataRep           = cell(numel(data), 1);
      for iData = 1:numel(data)
        dataRep{iData}  = obj.applyFormat(data{iData}, template.data);
      end
      
      %% Write at the given location -- N.B. we assume that the first row is the header
      try
        [~,sheetID]     = mat2sheets(database, sheet, [2,col], dataRep);
      catch err
        displayException(err);
        error('AnimalDatabase:writeDatabaseRow', 'Failed to write data into %s (researcher %s).', where, who);
      end
    end
    
    %----- Change the given sheet of the database to follow a new template, adding/removing columns if necessary
    function [didSomething, cancelled] = redactDatabase(obj, template, database, sheet, where, who)
      %% Retrieve raw data
      didSomething      = false;
      cancelled         = false;
      if iscell(database)
        data            = database;
      else
        data            = obj.readFromDatabase(database, sheet, where, who);
      end
      if isempty(data)
        return;
      end
      
      %% Try to match each column by header (1st row) to the template
      header            = strtrim(data(1,:));
      tmplField         = strtrim({template.field});
      [inTmpl,tmplIndex]= ismember( lower(header), lower(tmplField) );
      
      %% Verify with user in case any columns with data need to be deleted
      hasData           = ~cellfun(@isempty, strtrim(data(2:end,~inTmpl)));
      if any(hasData(:))
        notThere        = strcat({'        '}, header(~inTmpl));
        proceed         = questdlg( { 'Data has column(s) not present in the target template:', notThere{:}                     ...
                                    , sprintf('This will delete %d cell(s) with data in %s for %s.',sum(hasData(:)),where,who)  ...
                                    , 'Continue?'                                       ...
                                    }                                                   ...
                                  , sprintf('Redacting %s for %s',where,who)            ...
                                  , 'Yes', 'No', 'Cancel', 'No'                         ...
                                  );
        if strcmp(proceed, 'No')
          return;
        end
        if strcmp(proceed, 'Cancel')
          cancelled     = true;
          return;
        end
      end
      
      %% Make a new data array that spans the columns of both the original and the template
      redacted          = repmat({''}, size(data,1), max(size(data,2),numel(template)));
      redacted(:,tmplIndex(inTmpl))   = data(:,inTmpl);
      redacted(1,1:numel(tmplField))  = tmplField;
      if isequal(strtrim(data), strtrim(redacted))
        return;
      end

      %% Overwrite the entire sheet
      try
        mat2sheets(database, sheet, [1,1], redacted);
      catch err
        displayException(err);
        error('AnimalDatabase:redactDatabase', 'Failed to write data into %s for %s.', where, who);
      end
      didSomething      = true;
    end    
    
    
    %----- Change all existing animal listing sheets to match the current template, prompting the user if data needs to be modified
    function numChanged = redactAnimalLists(obj)
      %% Setup data source
      database        = AnimalDatabase.DATABASE_ID;
      where           = 'animal lists';
      numChanged      = 0;
      
      %% Always get the current template and database structure
      obj.pullOverview();
      for iID = 1:numel(obj.Researchers)
        fprintf(' ***  %15s : ', obj.Researchers(iID).ID);
        if isempty(obj.Researchers(iID).animalsGID)
          fprintf('(no animals)\n');
          continue;
        end
        
        [didSomething, cancelled]     ...
                      = obj.redactDatabase(obj.tmplAnimal, database, obj.Researchers(iID).animalsGID, where, obj.Researchers(iID).ID);
        if cancelled
          fprintf('CANCELLED by user.\n');
          return;
        end
        
        numChanged    = numChanged + didSomething;
        if didSomething
          fprintf('modified\n');
        else
          fprintf('no change\n');
        end
      end
    end
    
    %----- Change all existing animal daily logs to match the current template, prompting the user if data needs to be modified
    function numChanged = redactDailyLogs(obj)
      %% Always get the current animal lists and database structure
      [animals,researchers] = obj.pullAnimalList();
      numChanged            = 0;
      for iID = 1:numel(researchers)
        fprintf(' ***  %-15s', researchers(iID).ID);
        if isempty(animals{iID}) || isempty(researchers(iID).wateringLogs)
          fprintf('  (no animals/logs)\n');
          continue;
        end
        fprintf('\n');
        
        %% Setup data source
        database            = researchers(iID).wateringLogs;
        researcher          = obj.pullLogsStructure(researchers(iID).ID);
        sheetProps          = [researcher.logStructure.sheets.properties];
        where               = sprintf('daily logs (researcher %s)', researchers(iID).ID);
        
        %% Redact watering sheet only for the listed animals
        aniSheets           = sheetProps( ismember(lower({sheetProps.title}), lower({animals{iID}.ID})) );
        for iAni = 1:numel(aniSheets)
          fprintf('  |   %20s : ', aniSheets(iAni).title);
          drawnow;
          [didSomething, cancelled]     ...
                            = obj.redactDatabase(obj.tmplDailyInfo, database, int2str(aniSheets(iAni).sheetId), where, aniSheets(iAni).title);
          if cancelled
            fprintf('CANCELLED by user.\n');
            return;
          end
          
          numChanged        = numChanged + didSomething;
          if didSomething
            fprintf('modified\n');
          else
            fprintf('no change\n');
          end
        end
      end
    end
    

    %----- Convert string input (raw database entries) to a predefined format; checks for validity if mandatory 
    function [parsed, isValid] = parseAsFormat(obj, input, format, mandatory, allowSingle)
      if nargin < 4
        mandatory = false;
      end
      if nargin < 5
        allowSingle = false;
      end

      %% Use empty return value if not provided
      if isempty(input)
        parsed    = input;
        isValid   = ~mandatory;
        return;
      end
      
      %% Special case for multi-line entries
      multiFormat = regexp(format{2}, AnimalDatabase.RGX_MULTI_FORMAT, 'tokens' ,'once');
      if ~isempty(multiFormat)
        if iscell(input)
          parsed  = input;
        elseif size(input,1) > 1
          parsed  = num2cell(input, 2);
        else
          parsed  = strsplit(input, '\n');
        end
        
        %% Call standard parser on all lines
        format{2} = multiFormat{:};
        isValid   = false(size(parsed));
        for iElem = 1:numel(parsed)
          [parsed{iElem}, isValid(iElem)]   ...
                  = obj.parseAsFormat(parsed{iElem}, format, mandatory, allowSingle);
        end
        isValid   = all(isValid);
        return;
      end
      

      %% Define format options here
      isValid     = true;
      if strcmp(format{2}, 'IMAGE')
        %% Data is an RGB image encoded using base64
        parsed    = regexp(input, AnimalDatabase.RGX_IMG_FORMAT, 'tokens' ,'once');
        if isempty(parsed)
          error('AnimalDatabase:parseAsFormat', 'Invalid stored image: %s', input);
        end
        imgSize   = [str2double(parsed{1}), str2double(parsed{2}), 3];
        encoder   = org.apache.commons.codec.binary.Base64;
        parsed    = typecast(encoder.decodeBase64(uint8(parsed{3})), 'uint8');
        parsed    = reshape(parsed, imgSize);
        
      elseif strcmp(format{2}, 'RESPONSIBLE')
        %% Data should be a listed responsible
        parsed    = input;
        if ~any(strcmpi(parsed, {obj.Researchers.ID, obj.Technicians.ID, AnimalDatabase.ANI_HOME, AnimalDatabase.ANI_ENDLOC}))
          error('AnimalDatabase:parseAsFormat', 'Invalid responsible ID "%s", must be one of those in the database.', parsed);
        end
        
      elseif strcmp(format{2}, 'DATE')
        %% Data is a date formatted as month/day/year --- N.B. hardcoded Google default!
        parsed    = sscanf(input, AnimalDatabase.DATE_FORMAT);
        if numel(parsed) == 3
          parsed  = parsed([3 1 2])';           % HACK return in Matlab datevec format
          isValid = ( parsed(1) > 0 && parsed(1) < 10000 && parsed(2) < 13 && parsed(3) < 32 );
        else
          isValid = false;
        end
        
      elseif strcmp(format{2}, 'TIME')
        %% Data is a time indicator interpreted as HHMM 
        if ~isempty(strfind(input, ':'))
          parsed  = str2double(strsplit(input,':'));
        else
          parsed  = round(str2double(input));
        end
        AnimalDatabase.num2time(parsed);      % check validity
        
      elseif strcmp(format{2}, 'CHECK')
        %% Data is a list of items with a yes/no state
        parsed    = regexp(input, AnimalDatabase.RGX_NOTATED, 'tokens', 'lineanchors', 'dotexceptnewline');
        parsed    = cat(1, parsed{:});
        parsed(:,1) = cellfun(@(x) YesNoMaybe.(x), parsed(:,1), 'UniformOutput', false);
        
      elseif format{2}(1) == '['
        %% Data is a space-separated array
        format    = regexp(format{2}, AnimalDatabase.RGX_ARRAY_FORMAT, 'tokens' ,'once');
        format    = regexprep(format{:}, AnimalDatabase.RGX_PRECISION, '%');
        parsed    = regexp(input, AnimalDatabase.RGX_ARRAY_FORMAT, 'tokens' ,'once');
        if isempty(parsed)
          error('AnimalDatabase:parseAsFormat', 'Invalid format of array data: %s', input);
        end
        parsed    = strsplit(parsed{:});
        parsed    = accumfun(2, @(x) sscanf(x,format), parsed);
        
      elseif format{2}(1) == '?'
        %% Data is a member of a enumerated type
        if isnumeric(input)
          parsed  = eval(sprintf('%s(%d)', char(format{2}(2:end)), double(input)));
        else
          parsed  = eval([format{2}(2:end) '.' input]);
        end
        isValid   = ~mandatory || parsed ~= eval([format{2}(2:end) '.default']);
        
      elseif format{2}(1) == '#'
        %% Data is a member of a enumerated type repeated across days of the week
        parsed    = strsplit(input, '/', 'CollapseDelimiters', false);
        for iIn   = 1:numel(parsed)       % cellfun does not work to capture eval() outputs
          parsed{iIn} = eval([format{2}(2:end) '.' parsed{iIn}]);
        end
        parsed    = [parsed{:}];
        if ~allowSingle && numel(parsed) ~= numel(AnimalDatabase.DAYS_OF_WEEK)
          error('AnimalDatabase:parseAsFormat', 'Incorrect number %d of entries in "%s", should be %d.', numel(parsed), input, numel(AnimalDatabase.DAYS_OF_WEEK));
        end
        isValid   = ~mandatory || all(parsed ~= eval([format{2}(2:end) '.default']));
        
      elseif format{2}(1) == '@'
        %% Data is a simple numeric struct
        template  = ['tmpl' format{2}(2:end)];
        if ~isprop(obj, template)
          error('AnimalDatabase:parseAsFormat', 'struct template "%s" is missing.', template);
        end
        template  = obj.(template);
        parsed    = cellfun(@str2double, strsplit(input, '/', 'CollapseDelimiters', false));
        if numel(parsed) ~= numel(template)
          error('AnimalDatabase:parseAsFormat', 'Incorrect number %d of entries to parse as %s, should be %d.', numel(parsed), format{2}(2:end), numel(template));
        end
        isValid   = ~mandatory || all(isfinite(parsed));
        parsed    = cell2struct(num2cell(parsed), {template.data}, 2);
        
      elseif format{2}(1) == '*'
        %% Data is an unconstrained but assisted list of strings
        parsed    = input;
        
      elseif strcmp(format{2}, '%s')
        %% Data is a verbatim text string
        parsed    = input;
        
      else
        %% Data is given as a sscanf() format specifier
        format    = regexprep(format{2}, AnimalDatabase.RGX_PRECISION, '%');
        parsed    = sscanf(input, format);
        if isnumeric(parsed) && numel(parsed) > 1
          parsed  = parsed(:)';
        end
        isValid   = ~mandatory || ~isempty(parsed);
      end
    end
    
    %----- Format data into a string according to a predefined format
    function [str, number] = applyFormat(obj, input, format, allowSingle)
      
      if nargin < 4
        allowSingle = false;
      end
      
      %% Return an empty string for no info
      if isempty(input)
        str       = '';
        number    = [];
        return;
      end
      
      %% Special case for multi-line entries
      multiFormat = regexp(format{2}, AnimalDatabase.RGX_MULTI_FORMAT, 'tokens' ,'once');
      if isempty(multiFormat)
      elseif allowSingle && ~iscell(input)
        format{2} = multiFormat{:};
      else
        format{2} = multiFormat{:};
        [str, number] = cellfun(@(x) obj.applyFormat(x,format), input, 'UniformOutput', false);
        str       = strjoin(str, char(10));
        number    = [number{:}];
        return;
      end
      
      
      %% Define format options here
      number      = input;
      if strcmp(format{2}, 'IMAGE')
        %% Data is an RGB image which we have to encode using printable characters
        encoder   = org.apache.commons.codec.binary.Base64;
        str       = char(encoder.encodeBase64(input(:)))';
        str       = sprintf('%dx%d[%s]', size(input,1), size(input,2), str);
        
      elseif strcmp(format{2}, 'RESPONSIBLE')
        %% Data should be a listed responsible
        str       = input;
        number    = [];
        if ~any(strcmpi(str, {obj.Researchers.ID, obj.Technicians.ID, AnimalDatabase.ANI_HOME, AnimalDatabase.ANI_ENDLOC}))
          error('AnimalDatabase:applyFormat', 'Invalid responsible ID "%s", must be one of those in the database.', str);
        end
        
      elseif strcmp(format{2}, 'DATE')
        %% Data is a date formatted as month/day/year --- N.B. hardcoded Google default!
        str       = sprintf(AnimalDatabase.DATE_FORMAT, input(2), input(3), input(1));
        number    = AnimalDatabase.datenum2date(input);
        
      elseif strcmp(format{2}, 'TIME')
        %% Data is a time indicator interpreted as HHMM 
        [hour,minute] = AnimalDatabase.num2time(input);
        str       = sprintf('%02d:%02d', hour, minute);
        
      elseif strcmp(format{2}, 'CHECK')
        %% Data is a list of items with a yes/no state
        if iscellstr(input)
          tokens  = regexp(input, AnimalDatabase.RGX_NOTATED, 'tokens', 'once');
          if any(cellfun(@isempty, tokens))
            error('AnimalDatabase:applyFormat', 'CHECK input must have the format {''[check] description'',...}.');
          end
          str     = strjoin(input, char(10));
          number  = cat(1,tokens{:});
          number  = cellfun(@(x) double(YesNoMaybe.(x)), number(:,1))';
        elseif size(input,2) ~= 2
          error('AnimalDatabase:applyFormat', 'CHECK input must have exactly two columns.');
        elseif any(cellfun(@(x) ~isa(x,'YesNoMaybe'), input(:,1)))
          error('AnimalDatabase:applyFormat', 'The first column of CHECK input must be YesNoMaybe enumerated types.');
        else
          str     = arrayfun(@(x) sprintf('[%s]  %s',char(input{x,1}),input{x,2}), 1:size(input,1), 'UniformOutput', false);
          str     = strjoin(str, char(10));
          number  = input;
        end
        
      elseif format{2}(1) == '['
        %% Data is a space-separated array
        format    = regexp(format{2}, AnimalDatabase.RGX_ARRAY_FORMAT, 'tokens' ,'once');
        str       = arrayfun(@(x) sprintf(format{:},x), input, 'UniformOutput', false);
        str       = ['[', strjoin(str, ' ') ']'];
      
      elseif format{2}(1) == '?'
        %% Data is a member of a enumerated type
        str       = char(input);
        number    = double(input);

      elseif format{2}(1) == '#'
        %% Data is a member of a enumerated type repeated across days of the week
        str       = arrayfun(@(x) char(x), input, 'UniformOutput', false);
        str       = strjoin(str, '/');
        number    = double(input);
 
      elseif format{2}(1) == '@'
        %% Data is a simple numeric struct
        str       = {};
        for field = fieldnames(input)'
          if ischar(input.(field{:}))
            str{end+1}  = input.(field{:});
            input.(field{:})  = nan;
          elseif floor(input.(field{:})) == input.(field{:})
            str{end+1}  = sprintf('%d', input.(field{:}));
          else
            str{end+1}  = sprintf(AnimalDatabase.NUMBER_FORMAT, input.(field{:}));
          end
        end
        str       = strjoin(str, '/');
        number    = struct2array(input);
        
      elseif format{2}(1) == '*'
        %% Data is an unconstrained but assisted list of strings
        str       = strtrim(input);
        number    = [];
        
      elseif strcmp(format{2}, '%s') && isnumeric(input)
        %% Special case allowing conversion of numeric types to a string
        str       = num2str(input);
        
      else
        %% Data is given as a sscanf() format specifier
        str       = sprintf(format{2}, input);
        if ~isnumeric(input)
          number  = [];
        end
      end
    end
    
    %----- Return the suggested value according to a predefined format
    function value = suggestedForFormat(obj, format, data)
      %% Special case for multi-line entries
      multiFormat     = regexp(format{2}, AnimalDatabase.RGX_MULTI_FORMAT, 'tokens' ,'once');
      if ~isempty(multiFormat)
        format{2}     = multiFormat{:};
        value         = {obj.suggestedForFormat(format, data)};
        return;
      end
      
      %% Define format defaults here
      if strcmp(format{2}, 'CHECK')
        %% Data is a list of items with a yes/no state
        if isempty(format{3}) || format{3}(1) ~= '$' || ~isvarname(format{3}(2:end))
          error('AnimalDatabase:suggestedForFormat', 'CHECK items must be tied to a data variable that is a list to check.');
        end

        name          = format{3}(2:end);
        value         = {};
        for iData = 1:numel(data)
          if isfield(data{iData}, name)
            value     = data{iData}.(name);
            break;
          end
        end
        value         = [repmat({YesNoMaybe.Unknown},numel(value),1), value(:)];

      elseif ~isempty(strfind(format{3}, '$'))
        %% Evaluate a formula based on the given data structures
        formula       = format{3};
        vars          = regexp(formula, AnimalDatabase.RGX_VARIABLE, 'tokens');
        nSubbed       = 0;
        for iVar = 1:numel(vars)
          name        = vars{iVar}{:}(2:end);
          for iData = 1:numel(data)
            if ~isfield(data{iData}, name)
              continue;
            end
            if ~isempty(data{iData}.(name))
              value   = sprintf('%.10f', data{iData}.(name));
              formula = regexprep(formula, ['\' vars{iVar}{:} '\>'], value);
              nSubbed = nSubbed + 1;
            end
            break;
          end
        end
        
        %% Check if it is possible to fully evaluate this formula
        if nSubbed == numel(vars)
          value       = eval(formula);
        else
          value       = obj.emptyForFormat(format);
        end
        
      elseif ~isempty(format{3})
        %% Evaluate a fixed default value in the given format
        value         = obj.parseAsFormat(format{3}, format, false, true);
        if format{2}(1) == '#' && numel(value) == 1
          value       = repmat(value, size(AnimalDatabase.DAYS_OF_WEEK));
        end
        
      else
        %% Use a generic default value, replicated as necessary
        value         = obj.emptyForFormat(format, 1);
        if format{2}(1) == '#'
          value       = repmat(value, size(AnimalDatabase.DAYS_OF_WEEK));
        end
      end
    end
    
    %----- Return an empty value for a predefined format; this signifies no information provided
    function value = emptyForFormat(obj, format, outSize)
      if nargin < 3 || isempty(outSize)
        outSize = 0;
      end
      
      %% Generate a singleton of the desired type
      if format{2}(1) == '?' || format{2}(1) == '#'
        value   = eval([format{2}(2:end) '.default']);
      elseif format{2}(1) == '@'
        template= obj.(['tmpl' format{2}(2:end)]);
        value   = nan(1, numel(template));
      elseif format{2}(1) == '*'
        value   = '';
      elseif strcmp(format{2}, 'TIME')
        value   = nan;
      elseif ~isempty(regexp(format{2}, '%[0-9]*[.]?[0-9]*[fg]', 'match', 'once'))
        value   = nan;
      else
        value   = '';
      end
      
      %% Convert to an empty array
      value     = repmat(value, outSize);
    end

    
    %----- Apply suggested values to all empty entries in a log structure
    function data = suggestValues(obj, template, data, supportData)
      for iData = 1:numel(data)
        %% Replace empty data with suggested values 
        evalData      = [{data}, supportData];
        for iVar = 1:numel(template)
          if ~isempty(data.(template(iVar).identifier))
            continue;
          end

          value       = obj.suggestedForFormat(template(iVar).data, evalData);
%           if isempty(value)
%             value     = obj.emptyForFormat(template(iVar).data, 1);
%           end
          data.(template(iVar).identifier)  = value;
        end
      end
    end
    
    %----- Get the next date in which changes can be made effective
    function effective = changeEffectiveDate(obj)
      hours       = now() - floor(now());
      cutoff      = AnimalDatabase.time2days(obj.NotificationSettings.ChangeCutoffTime);
      if hours > cutoff
        effective = floor(now()) + 1;
      else
        effective = floor(now());
      end
      effective   = datevec(effective);
    end
    
    
    %----- Find the information structure/index of a researcher by ID; calls pullOverview() if needed
    function [info, index] = findResearcher(obj, researcherID, forceUpdate)
      if ~isstruct(obj.Researchers) || (nargin > 2 && isequal(forceUpdate, true))
        obj.pullOverview();
      end
      
      index   = find(strcmpi({obj.Researchers.ID}, researcherID));
      if isempty(index)
        error('AnimalDatabase:findResearcher', 'Researcher with ID = %s does not exist.', researcherID);
      elseif numel(index) ~= 1
        error('AnimalDatabase:findResearcher', 'Multiple researchers matching ID = %s, everybody must be unique!', researcherID);
      end
      info    = obj.Researchers(index);
    end
    
    %----- Find the information structure/index of a tech by ID; calls pullOverview() if needed
    function [info, index] = findTechnician(obj, techID, forceUpdate)
      if ~isstruct(obj.Technicians) || (nargin > 2 && isequal(forceUpdate, true))
        obj.pullOverview();
      end
      
      index   = find(strcmpi({obj.Technicians.ID}, techID));
      if isempty(index)
        error('AnimalDatabase:findTechnician', 'Technician with ID = %s does not exist.', techID);
      elseif numel(index) ~= 1
        error('AnimalDatabase:findTechnician', 'Multiple technicians matching ID = %s, everybody must be unique!', techID);
      end
      info    = obj.Technicians(index);
    end
    
    %----- Find the information structure/index of a person, whether technician or researcher
    function [info, isATech, index] = findSomebody(obj, personID, forceUpdate)
      if ~isstruct(obj.Technicians) || ~isstruct(obj.Researchers) || (nargin > 2 && isequal(forceUpdate, true))
        obj.pullOverview();
      end
      
      iTech       = find(strcmpi({obj.Technicians.ID}, personID));
      iResearcher = find(strcmpi({obj.Researchers.ID}, personID));
      if isempty(iTech) && isempty(iResearcher)
        error('AnimalDatabase:findTechnician', 'Nobody with ID = %s exists.', personID);
      elseif numel(iTech) + numel(iResearcher) > 1
        error('AnimalDatabase:findTechnician', 'Multiple people matching ID = %s, everybody must be unique!', personID);
      elseif ~isempty(iTech)
        info      = obj.Technicians(iTech);
        isATech   = true;
        index     = iTech;
      else
        info      = obj.Researchers(iResearcher);
        isATech   = false;
        index     = iResearcher;
      end
    end
    
    %----- Find the information structure/index of one or more animals given a researcher they belong to
    function [info, index, researcher] = findAnimal(obj, researcherID, animalID, forceUpdate)
      if ~isstruct(obj.Researchers) || (nargin > 3 && isequal(forceUpdate, true))
        [~,researcher]    = obj.pullAnimalList(researcherID);
      else
        researcher        = obj.findResearcher(researcherID);
        if isempty(researcher.animals)
          [~,researcher]  = obj.pullAnimalList(researcherID);
        end
      end
      
      [found,index]       = ismember(lower(animalID), lower({researcher.animals.ID}));
      if any(~found)
        if iscell(animalID)
          animalID        = strjoin(animalID,', ');
        end
        error('AnimalDatabase:findAnimal', 'Animal(s) with ID = %s do not exist for researcher %s.', animalID, researcherID);
      end
      info                = researcher.animals(index);
    end
    
    
    %----- Find the tech on duty today; calls pullOverview() if needed
    function [tech, index] = techOnDuty(obj, forceUpdate)
      if ~isstruct(obj.Technicians) || (nargin > 2 && isequal(forceUpdate, true))
        obj.pullOverview();
      end
 
      %% Get the assigned technician today
      iToday  = weekday(now());
      tech    = obj.DutyRoster(iToday).Technician;
      index   = find(strcmpi({obj.Technicians.ID}, tech));
      tech    = obj.Technicians(index);
      
      %% In case the tech is not available, assign the first available tech
      if ~strcmpi(tech.Presence, 'available')
        index = find(strcmpi({obj.Technicians.Presence}, 'available'));
        tech  = obj.Technicians(index);
      end
    end
    
    %----- Find the list of researchers whose animals are the primary/secondary responsibilities of a given person
    function [primary, secondary] = whatShouldIDo(obj, personID)
      if ~isstruct(obj.Technicians)
        obj.pullOverview();
      end
      
      if any(strcmpi({obj.Technicians.ID}, personID))
        hasTech         = strcmpi({obj.Researchers.TechResponsibility}, 'yes');
        primary         = obj.Researchers(hasTech);
        secondary       = repmat(obj.Researchers,0);
      else
        primary         = obj.findResearcher(personID);       % must always be responsible for yourself
        isSecondary     = strcmpi({obj.Researchers.SecondaryContact}, personID);
        secondary       = obj.Researchers(isSecondary);
      end
    end
    
    %----- Finds for a given researcher the list of owned animals and their responsibles for today
    function [tech, primary, secondary, researcher, animals] = whoCaresForMe(obj, researcherID)
      %% Default arguments
      obj.pullOverview();                     % always update database in case availability has changed
      singleton           = false;
      if nargin < 2 || isempty(researcherID)
        researcherID      = {obj.Researchers.ID};
      elseif ischar(researcherID)
        researcherID      = {researcherID};
        singleton         = true;
      end

      %% Loop through researchers 
      techToday           = obj.techOnDuty();
      [animals,researcher]= obj.pullAnimalList(researcherID);
      tech                = cell(size(researcherID));
      primary             = cell(size(researcherID));
      secondary           = cell(size(researcherID));
      for iID = 1:numel(researcherID)
        %% If the researcher is working with a tech, assign the tech on duty
        if strcmpi(researcher(iID).TechResponsibility, 'yes')
          tech{iID}       = techToday;
        end
        
        %% Gather the list of available responsibles
        responsibles      = [researcher(iID), obj.findResearcher(researcher(iID).SecondaryContact)];
        responsibles( ~strcmpi({responsibles.Presence}, 'available') )  = [];
        
        %% Promote secondary contacts if necessary
        if ~isempty(responsibles)
          primary{iID}    = responsibles(1);
        end
        if numel(responsibles) > 1
          secondary{iID}  = responsibles(2);
        end
      end
      
      %% Convenience for return type
      if singleton
        tech              = tech{:};
        primary           = primary{:};
        secondary         = secondary{:};
        animals           = animals{:};
      end
    end    
    
    %----- Apply date selection to futurePlans entries in an animal info struct 
    function animal = whatIsThePlan(obj, animal, allowFuture, allowEmpty)
      %% Default arguments
      if nargin < 3
        allowFuture     = false;
      end
      if nargin < 4
        allowEmpty      = false;
      end
      
      %% Identify which fields correspond to future plans
      futurePlans       = {obj.tmplAnimal(strcmpi({obj.tmplAnimal.futurePlans}, 'yes')).identifier};
      when              = now();
      cutoff            = AnimalDatabase.time2days(obj.NotificationSettings.ChangeCutoffTime);
        
      for iAni = 1:numel(animal)
        if isempty(animal(iAni).effective)
          %% Require that all animals have an associated handling plan
          if ~allowEmpty
            error('AnimalDatabase:whatIsThePlan', 'Animal %s of researcher %s does not have an associated handling plan.', animal(iAni).ID, animal(iAni).owner);
          end
          
        elseif allowFuture
          %% Select the latest plan, including with future effective dates
          for iPlan = 1:numel(futurePlans)
            animal(iAni).(futurePlans{iPlan})     ...
                        = animal(iAni).(futurePlans{iPlan}){end};
          end
          
        else
          %% Select the plan that is currently in effect
          effective     = cellfun(@(x) datenum(x) + cutoff, animal(iAni).effective);
          planIndex     = find(effective <= when, 1, 'last');
          if isempty(planIndex)
%             warning('AnimalDatabase:whatIsThePlan', 'All handling plans for %s have an effective date in the future. This is normal for newly entered animals but otherwise means that something strange is afoot.', animal(iAni).ID);
            planIndex   = 1;
          end
          
          for iPlan = 1:numel(futurePlans)
            animal(iAni).(futurePlans{iPlan})     ...
                        = animal(iAni).(futurePlans{iPlan}){planIndex};
          end
        end
      end
    end
    
    %----- Returns true if action should be taken by a responsible for a given mouse 
    function [yes, techDuty, animal, isATech] = shouldICare(obj, animal, person, forNotifications, forWatering)
      if nargin < 4 || isempty(forNotifications)
        forNotifications  = false;
      end
      if nargin < 5 || isempty(forWatering)
        forWatering       = false;
      end
      
      %% Get supporting info about whether the person is a tech and whether on duty
      if ischar(person)
        [person,isATech]  = obj.findSomebody(person);
      else
        isATech           = ~isfield(person, 'TechResponsibility');
      end
      
      dayIndex            = weekday(now());
      animal              = obj.whatIsThePlan(animal, false);           % in effect now
      hasPrimaryTech      = strcmpi(obj.techOnDuty.primaryTech, 'yes');
      
      %% Loop through animals
      yes                 = false(size(animal));
      techDuty            = repmat(Responsibility.Nothing, size(animal));
      for iAni = 1:numel(animal)
        %% Only animals under water restriction require attention
        if    animal(iAni).status < HandlingStatus.InExperiments          ...
          ||  animal(iAni).status > HandlingStatus.WaterRestrictionOnly
          continue;
        end
        
        %% Overall handling status overrides day-to-day tech duties
        researcher        = obj.findResearcher(animal(iAni).owner);
        if strcmpi(researcher.TechResponsibility, 'no')
          techDuty(iAni)  = Responsibility.Nothing;
        elseif animal(iAni).status == HandlingStatus.WaterRestrictionOnly
          techDuty(iAni)  = Responsibility.Water;
        elseif hasPrimaryTech
          techDuty(iAni)  = animal(iAni).techDuties(dayIndex);
        elseif animal(iAni).techDuties(dayIndex) < Responsibility.Transport
          techDuty(iAni)  = Responsibility.Nothing;
        else
          techDuty(iAni)  = Responsibility(min(animal(iAni).techDuties(dayIndex), Responsibility.Water));
        end
        
        %% Special case where the primary is away, to make sure somebody waters the mouse
        if ~strcmpi(researcher.Presence,'available') && strcmpi(researcher.TechResponsibility,'yes')
          techDuty(iAni)  = Responsibility(max(animal(iAni).techDuties(dayIndex), Responsibility.Water));
        end
        
        %% Decide on responsibility based on role of the person (tech/primary/secondary/other)
        if isATech                                % tech
          yes(iAni)       = techDuty(iAni) ~= Responsibility.Nothing;
        elseif forWatering                        % primary can be in charge of getting water
          yes(iAni)       = techDuty(iAni) < Responsibility.Water;
        else                                      % primary can be in charge of weighing/returning 
          yes(iAni)       = techDuty(iAni) < Responsibility.Weigh || forNotifications;
        end
        
        % Special case for secondary who takes over a limited set of roles and only if the primary is away
        if ~isATech && yes(iAni) && ~strcmpi(person.ID,researcher.ID)
          yes(iAni)       = ~strcmpi(researcher.Presence,'available') && strcmpi(person.ID,researcher.SecondaryContact);
        end
      end

    end
    
    %----- Returns a descriptive location for the cage depending on the animals' statuses and where they are
    function [location, description, animal] = whereIsThisThing(obj, animal, personID)
      animal            = obj.whatIsThePlan(animal);

      %% Background color depends on where the cage is at right now
      cageLoc           = unique({animal.whereAmI});
      if any(ismember([animal.status], AnimalDatabase.EMERGENCY_STATUS))
        location        = LocationState.Unknown;
        description     = 'I''m lost, HELP me!';
      elseif any(strcmpi(cageLoc, personID))
        location        = LocationState.WithYou;
        description     = 'Checked out by YOU';
      elseif numel(cageLoc) ~= 1
        location        = LocationState.Everywhere;
        description     = ['I''m confused and in many places: ' strjoin(cageLoc,', ')];
      elseif isempty(cageLoc{:})
        location        = LocationState.Unknown;
        description     = 'I''m nowhere, fix me!';
      elseif strcmpi(cageLoc{:}, AnimalDatabase.ANI_HOME)
        location        = LocationState.AtHome;
        description     = ['At home in ' AnimalDatabase.ANI_HOME];
      else
        location        = LocationState.WithAnother;
        description     = ['In the care of ' cageLoc{:}];
      end
    end
    
    
    %----- Ensure that an animal listing sheet exists for the given researcher, creating one if necessary
    function [gid, researcher, isNew, index] = openAnimalList(obj, researcherID, createIfNecessary)
      [researcher,index]  = obj.findResearcher(researcherID);
      database            = AnimalDatabase.DATABASE_ID;
      if nargin < 3 || createIfNecessary
        createIfNecessary = true;
      end

      %% Check if there is a recorded sheet in the database
      if ~isempty(researcher.animalsGID)
        %% In case of immediate success, check that the sheet actually exists (could have been deleted)
        if obj.testDataAccess(database, researcher.animalsGID)
          isNew           = false;
        elseif ~createIfNecessary
          error('AnimalDatabase:openAnimalList', 'No animal list sheet found for researcher %s.', researcherID);
        else
          mat2sheets(database, researcher.Name);
          obj.Researchers(index).animalsGID         ...
                          = ['!' researcher.Name];                      % lookup new sheet by title
          researcher      = obj.Researchers(index);
          isNew           = true;
        end
        
        gid               = researcher.animalsGID;
        return;
      end
        
      %% If there is no recorded sheet, update the database and try again (someone made it?)
      [researcher,index]  = obj.findResearcher(researcherID, true);     % force update
      if ~isempty(researcher.animalsGID)
        isNew             = false;
        gid               = researcher.animalsGID;
        return;
      end
      
      %% If there is no sheet, create one and update the database
      if ~createIfNecessary
        error('AnimalDatabase:openAnimalList', 'No animal list sheet found for researcher %s.', researcherID);
      end
      
      mat2sheets(database, researcher.Name);
      obj.Researchers(index).animalsGID         ...
                          = ['!' researcher.Name];                      % lookup new sheet by title
      researcher          = obj.Researchers(index);
      isNew               = true;
      gid                 = researcher.animalsGID;
    end

    %----- Ensure that a daily information sheet exists for the given researcher and animal, creating one if necessary
    function [gid, researcher, isNew, index] = openDailyLogs(obj, researcherID, animalID, createIfNecessary)
      if nargin < 4
        createIfNecessary     = true;
      end
      
      %% Locate the watering logs spreadsheet and get its structure if necessary
      [researcher,refreshed]  = obj.pullLogsStructure(researcherID);
      where                   = 'watering logs';
      database                = researcher.wateringLogs;

      %% Check if there is a recorded sheet in the database
      [gid,researcher,~,index]= obj.findDailyLogsID(researcher, animalID, ~refreshed, where);
      if ~isempty(gid) && obj.testDataAccess(database, gid)
        isNew                 = false;
      elseif ~createIfNecessary
        error('AnimalDatabase:openDailyLogs', 'No daily logs sheet found for animal %s of researcher %s.', animalID, researcherID);
      else
        isNew                 = true;
        mat2sheets(database, animalID);
        gid                   = ['!' animalID];
      end
    end
    
    
    %----- Read remote information to get the list of available researchers etc.
    function [overview, templates] = pullOverview(obj)
      %% Get database structure information to lookup sheets etc.
      database          = AnimalDatabase.DATABASE_ID;
      where             = 'mice database';
      obj.dbStructure   = mat2sheets(database);
      peopleID          = AnimalDatabase.findSheetID('Responsibles', obj.dbStructure, where, '', false);
      
      %% Get the list of responsibles, by category
      overview          = obj.readFromDatabase(database, peopleID, where);
      overview          = AnimalDatabase.parseDataSpecs(overview);
      allPeople         = {};
      for field = fieldnames(overview)'
        %% Parse special fields by name
        for data = fieldnames(overview.(field{:}))'
          if ~isempty(strfind(data{:}, 'Time'))
            for iCol = 1:numel(overview.(field{:}))
              overview.(field{:})(iCol).(data{:})     ...
                        = obj.parseAsFormat(overview.(field{:})(iCol).(data{:}), AnimalDatabase.SPECS_TIME);
            end
          end
        end
        
        %% Collect people list
        if isfield(overview.(field{:}), 'ID')
          allPeople     = [allPeople, {overview.(field{:}).ID}];
        end
        
        %% Store for future access
        obj.(field{:})  = overview.(field{:});
      end
      
      if numel(unique(allPeople)) ~= numel(allPeople)
        error('AnimalDatabase:people', 'One or more responsibles have the same ID. This must be fixed via Google Spreadsheets. The current list is: %s', strjoin(allPeople,', '));
      end
      
      %% Parse watering log URLs, if present
      for iID = 1:numel(obj.Researchers)
        if isempty(obj.Researchers(iID).wateringLogs) || ~ischar(obj.Researchers(iID).wateringLogs)
          obj.Researchers(iID).wateringLogs = '';
          continue;
%           error('AnimalDatabase:wateringLogs', 'wateringLogs URL is empty or invalid for researcher %s. This must be fixed via Google Spreadsheets.', obj.Researchers(iID).Name);
        end
        url             = regexp(obj.Researchers(iID).wateringLogs, AnimalDatabase.RGX_DOC_URL, 'tokens', 'once');
        if isempty(url)
          error('AnimalDatabase:wateringLogs', 'wateringLogs URL has an incorrect format for researcher %s. This must be fixed via Google Spreadsheets.', obj.Researchers(iID).Name);
        end
        obj.Researchers(iID).wateringLogs = url{1};
      end
      
      %% Get sheet IDs and other special fields for animal lists of the corresponding researcher
      sheetProps        = [obj.dbStructure.sheets.properties];
      for iID = 1:numel(obj.Researchers)
        personIndex     = find(strcmpi({sheetProps.title}, obj.Researchers(iID).Name));
        if numel(personIndex) > 1
          error('AnimalDatabase:pullOverview', 'Multiple information sheets found for researcher %s.', obj.Researchers(iID).Name);
        elseif isempty(personIndex)
          obj.Researchers(iID).animalsGID   = [];
        else
          obj.Researchers(iID).animalsGID   = num2str(sheetProps(personIndex).sheetId);
        end
        
        obj.Researchers(iID).animals        = [];
        obj.Researchers(iID).logStructure   = [];
        if isnumeric(obj.Researchers(iID).Protocol)
          obj.Researchers(iID).Protocol     = num2str(obj.Researchers(iID).Protocol);
        end
      end
      
      
      %% Read all templates
      templates         = obj.readFromDatabase(database, [], where, 'template');
      templates         = AnimalDatabase.parseDataSpecs(templates);
      for field = fieldnames(templates)'
        tmpl            = templates.(field{:});
        if ~isfield(tmpl, 'grouping')
          obj.(['tmpl' field{:}]) = tmpl;
          continue;
        end

        %% Parse special fields of templates
        for iTmpl = 1:numel(tmpl)
          %% Enforce grouping info format: either blank or a single character
          if isempty(tmpl(iTmpl).grouping)
            tmpl(iTmpl).grouping  = nan;
          elseif ~ischar(tmpl(iTmpl).grouping) || numel(tmpl(iTmpl).grouping) > 1
            error('AnimalDatabase:template', 'Template grouping specification must be either blank or a single character');
          else
            tmpl(iTmpl).grouping  = double(tmpl(iTmpl).grouping);
          end
          
          %% Parse data format specifiers
          format        = regexp(tmpl(iTmpl).data, AnimalDatabase.RGX_FIELD_FORMAT, 'tokens', 'once');
          if isempty(format) || isempty(format{1}) || isempty(format{2})
            error('AnimalDatabase:template', 'Invalid format specifier "%s" in %s template.', tmpl(iTmpl).data, field{:});
          end
          if ~isempty(format{3})
            format{3}   = strtrim(format{3}(2:end));
          end
          tmpl(iTmpl).data        = format;
        end
        
        %% Store templates for future use
        obj.(['tmpl' field{:}])   = tmpl;
      end
    end
    
    %----- Read mouse listing given a researcher (can be multiple, by default all)
    function [animals, researchers, template] = pullAnimalList(obj, researcherID)
      %% Default arguments
      singleton           = false;
      if nargin < 2 || isempty(researcherID) || isempty(obj.tmplAnimal)
        obj.pullOverview();                             % update database
        researcherID      = {obj.Researchers.ID};
      elseif ischar(researcherID)
        researcherID      = {researcherID};
        singleton         = true;
      end

      %% Setup data source
      database            = AnimalDatabase.DATABASE_ID;
      where               = 'mice database';
      dataRow             = 2;      % right after header
      template            = obj.tmplAnimal;
      
      %% Loop through researchers and their data sheets
      animals             = cell(size(researcherID));
      researchers         = cell(size(researcherID));
      for iID = 1:numel(researcherID)
        %% Read animal list from database sheet for this researcher
        [researcher,index]= obj.findResearcher(researcherID{iID});
        if isempty(researcher.animalsGID)
          animals{iID}    = AnimalDatabase.emptyLike(template);
        else
          data            = obj.readFromDatabase(database, researcher.animalsGID, where, researcher.Name);
          if isempty(data)
            %% Populate column headers from template 
            animals{iID}  = obj.copyTemplateInfo(template, 1, database, researcher.animalsGID, where, researcher.Name);
          else
            %% Keep animal list in sorted order
            animals{iID}  = obj.parseFromDatabase(template, dataRow, data, researcher.animalsGID, where, researcher.Name);
            iOrder        = obj.sortDatabase(data(dataRow:end,:), [{animals{iID}.cage}; {animals{iID}.ID}]', dataRow, database, researcher.animalsGID, where, researcher.Name);
            if ~isempty(iOrder)
              animals{iID}= animals{iID}(iOrder);
            end
          end
        end
        
        %% Store animal's identification image for tooltips
        imageDir          = fullfile(AnimalDatabase.DIR_ANIIMAGE, researcherID{iID});
        if ~exist(imageDir, 'dir')
          mkdir(imageDir);
        end
        for iAni = 1:numel(animals{iID})
          animals{iID}(iAni).imageFile              ...
                          = fullfile(imageDir, [animals{iID}(iAni).ID, '.png']);
          if ~isempty(animals{iID}(iAni).image)
            imwrite(imresize(animals{iID}(iAni).image,2), animals{iID}(iAni).imageFile);
          elseif exist(animals{iID}(iAni).imageFile, 'file')
            delete(animals{iID}(iAni).imageFile);
          end
        end
        
        %% Store under researcher's entry for future lookup
        [animals{iID}.imageFile]  = deal([]);
        [animals{iID}.owner]      = deal(researcherID{iID});
        obj.Researchers(index).animals              ...
                          = animals{iID};
        researchers{iID}  = obj.Researchers(index);
      end
      
      %% Convenience for return type
      researchers         = [researchers{:}];
      if singleton
        animals           = animals{:};
      end
    end
    
    %----- Read daily log information given a single researcher and possibly multiple animals (default all)
    function [logs, animals, sheetID, template] = pullDailyLogs(obj, researcherID, animalID)
      %% Default arguments
      singleton           = false;
      if nargin < 3
        animalID          = [];
      elseif ischar(animalID)
        singleton         = true;
        animalID          = {animalID};
      end
      
      %% Setup data source
      [researcher, refreshed] = obj.pullLogsStructure(researcherID);
      database            = researcher.wateringLogs;
      where               = 'watering logs';
      dataRow             = 2;      % right after header
      template            = obj.tmplDailyInfo;
      
      %% Sanity check that the requested animals exist in the database
      if ~isstruct(researcher.animals)
        obj.pullAnimalList(researcherID);
        researcher        = obj.findResearcher(researcherID);
      end
      
      if isempty(animalID)
        animalID          = {researcher.animals.ID};
      elseif any(~ismember(lower(animalID), lower({researcher.animals.ID})))
        invalidID         = animalID(~ismember(lower(animalID), lower({researcher.animals.ID})));
        error('AnimalDatabase:pullDailyLogs', 'Requested animal(s) for %s do not exist: %s', researcher.Name, strjoin(invalidID, ', '));
      end
      
      %% Loop through animals
      logs                = cell(size(animalID));
      animals             = cell(size(animalID));
      sheetID             = cell(size(animalID));
      for iAni = 1:numel(animalID)
        animal            = researcher.animals( strcmpi({researcher.animals.ID}, animalID{iAni}) );
        animals{iAni}     = animal;
        if numel(animal) > 1
          error('AnimalDatabase:pullDailyLogs', 'Multiple animal list entries found for animal %s of researcher %s.', animalID{iAni}, researcher.Name);
        end
        
        %% Try to find the daily sheet for this animal with cached info if possible
        [sheetID{iAni}, researcher, refresh2]               ...
                          = obj.findDailyLogsID(researcher, animalID{iAni}, ~refreshed, where);
        refreshed         = refreshed || refresh2;
        if isempty(sheetID{iAni})
          continue;
        end

        %% If sheet is empty, populate from template
        data              = obj.readFromDatabase(database, sheetID{iAni}, where, researcher.Name);
        if isempty(data)
        else
          logs{iAni}      = obj.parseFromDatabase(template, dataRow, data, sheetID{iAni}, where, researcher.Name);
        end
      end
      
      %% Convenience for return type
      if singleton
        logs              = logs{:};
        animals           = animals{:};
        sheetID           = sheetID{:};
      else
        animals           = [animals{:}];
      end
    end
    
    
    %----- Write animal-specific information for a single animal; specify as pairs e.g. 'protocol', '1910', 'sex', Sex.Female, ...
    function [animal, researcher] = pushAnimalInfo(obj, researcherID, animalID, varargin)
      varargin          = AnimalDatabase.checkPairInput(varargin, 'Animal information to set');
      
      %% Setup data source
      database          = AnimalDatabase.DATABASE_ID;
      where             = ['information for ' animalID];
      [gid, researcher, isNew, iResearcher]       ...
                        = obj.openAnimalList(researcherID);
      if isNew
        template        = obj.tmplAnimal;
        [list, gid]     = obj.copyTemplateInfo(template, 1, database, gid, where, researcher.Name);
        obj.Researchers(iResearcher).animalsGID   = gid;
        researcher      = obj.Researchers(iResearcher);
      else
        [list,~,template] = obj.pullAnimalList(researcherID);
      end
      
      %% Find the location at which to output information 
      dataRow           = find(strcmpi({list.ID}, animalID));
      if numel(dataRow) > 1
        error('AnimalDatabase:pushAnimalInfo', 'More than one animal found with ID = %s for researcher %s.', animalID, researcherID);
      end
      
      %% Add a row for a new animal if necessary
      if isempty(dataRow)
        dataRow         = numel(list) + 1;
        for iField = 1:numel(template)
          list(dataRow).(template(iField).identifier)       ...
                        = obj.emptyForFormat(template(iField).data);
        end
        list(dataRow).ID= animalID;
        list(dataRow).whereAmI  = AnimalDatabase.ANI_HOME;
      end
      animal            = list(dataRow);
      
      %% Merge the specified information into the row data structure
      hasPlans          = isfield(template, 'futurePlans');
      for iArg = 1:2:numel(varargin)-1
        if ~ischar(varargin{iArg})
          error('AnimalDatabase:pushAnimalInfo', 'Identifiers to set must be strings.');
        end
        if ~isfield(list, varargin{iArg})
          error('AnimalDatabase:pushAnimalInfo', 'Invalid identifier %s for data to set --- are you sure this is part of the general animal information database (as opposed to daily logs)?', varargin{iArg});
        end
        
        %% Special case for futurePlans: concatenate data instead of replacing
        if ~hasPlans || strcmpi(template(strcmp({template.identifier},varargin{iArg})).futurePlans, 'no')
          animal.(varargin{iArg})         = varargin{iArg+1};
        elseif iscell(varargin{iArg+1})
          animal.(varargin{iArg})         = [animal.(varargin{iArg}), varargin{iArg+1}];
        else
          animal.(varargin{iArg}){end+1}  = varargin{iArg+1};
        end
      end
      
      %% Ensure that there is at most one change of plans per day by selecting the last decision
      if hasPlans && ~isempty(animal.effective)
        [~,iPlan]       = unique(cat(1,animal.effective{:}), 'rows', 'legacy');
        for plan = {template(strcmpi({template.futurePlans}, 'yes')).identifier}
          animal.(plan{:}) = animal.(plan{:})(iPlan);
        end
      end
      
      %% Write the entire row in string format
      obj.writeDatabaseRow(animal, template, dataRow+1, database, gid, where, researcher.Name);
      animal.owner      = researcherID;
      obj.Researchers(iResearcher).animals(dataRow) = animal;
      
       %% insert the data into datajoint database
        
       % insert subject info
        key_subj = struct(...
           'user_id', animal.owner, ...
           'subject_id', animal.ID);
       
        subj = key_subj;
       
        if isempty(fetch(subject.Subject & key_subj))
            exists = 0;
        else 
            exists = 1;
        end
        
        if ~isempty(animal.sex)
            if exists
                update(subject.Subject & key_subj, 'sex', animal.sex.char)
            else
                subj.sex = animal.sex.char;
            end
        end
        
        if ~isempty(animal.dob)
            dob = sprintf('%d-%02d-%02d', animal.dob(1), animal.dob(2), animal.dob(3));
            if exists
                update(subject.Subject & key_subj, 'dob', dob)
            else
                subj.dob = dob;
            end
        end

        if ~isempty(animal.image)
            if exists
                update(subject.Subject & key_subj, 'head_plate_mark', animal.image)
            else
                subj.head_plate_mark = animal.image;
            end
        end

        if ~isempty(animal.whereAmI)
            if exists
                update(subject.Subject & key_subj, 'location', animal.whereAmI)
            else
                subj.location = animal.whereAmI;
            end
        end

        if ~isempty(animal.protocol)
            if exists
                update(subject.Subject & key_subj, 'protocol', animal.protocol)
            else
                subj.protocol = animal.protocol;
            end
        end

        if ~isempty(animal.initWeight)
            if exists
                update(subject.Subject & key_subj, 'initial_weight', animal.initWeight)
            else
                subj.initial_weight = animal.initWeight;
            end
        end

        if ~isempty(animal.genotype)
            if exists
                update(subject.Subject & key_subj, 'line', animal.genotype)
            else
                subj.line = animal.genotype;
            end
        else
            subj.line = 'Unknown';
        end
        
        if ~exists
            insert(subject.Subject, subj)
        end
        
       
        % insert cage info
        key_cage.cage = animal.cage;
        cage = key_cage;
        cage.cage_owner = animal.owner;
        
        if isempty(fetch(subject.Cage & key_cage))
            insert(subject.Cage, cage)
        else 
            update(subject.Cage & key_cage, 'cage_owner', animal.owner)
        end
        
        % insert caging status
        caging_status = key_subj;
        caging_status.cage = animal.cage;
        if isempty(fetch(subject.CagingStatus & key_subj))
            insert(subject.CagingStatus, caging_status)
        else
            update(subject.CagingStatus & key_subj, 'cage', animal.cage)
        end
        
        % insert subject status
        if ~isempty(animal.status)
            key_subj_status = key_subj;
            for i = 1:length(animal.status)
                effective = animal.effective{i};
                key_subj_status.effective_date = sprintf(...
                    '%d-%02d-%02d', effective(1), effective(2), effective(3));
                subj_status = key_subj_status;
                subj_status.subject_status = animal.status{i}.char;
                
                if strcmp(subj_status.subject_status, 'Dead')
                    if ~isempty(fetch(subject.Death & key_subj))
                        update(subject.Death & key_subj, 'death_date', ...
                            key_subj_status.effective_date)
                    else
                        death = key_subj;
                        death.death_date = key_subj_status.effective_date;
                        insert(subject.Death, death)
                    end
                    return
                end
                
                if ismember(subj_status.subject_status, {'Missing', 'Unknown'})
                    if ~isempty(fetch(action.SubjectStatus & key_subj_status))
                        insert(action.SubjectStatus, subj_status)
                    else
                        update(action.SubjectStatus & key_subj_status, 'subject_status', subj_status.subject_status)
                        update(action.SubjectStatus & key_subj_status, 'water_per_day')
                        update(action.SubjectStatus & key_subj_status, 'schedule')
                    end
                else
                    subj_status.water_per_day = animal.waterPerDay{i};
                    subj_status.schedule = strjoin(animal.techDuties{i}.string, '/');
                    if ~isempty(fetch(action.SubjectStatus & key_subj_status))
                        update(action.SubjectStatus & key_subj_status, 'subject_status', subj_status.subject_status)
                        update(action.SubjectStatus & key_subj_status, 'water_per_day', subj_status.water_per_day)
                        update(action.SubjectStatus & key_subj_status, 'schedule', subj_status.schedule)
                    else
                        insert(action.SubjectStatus, subj_status)
                    end
                end
            end
        end
        
        % insert subject actItem
        if ~isempty(animal.actItems)
            for i = 1:length(animal.actItems)
                subj_act_item = key_subj;
                subj_act_item.act_item = animal.actItems{i};
                if isempty(fetch(subject.SubjectActItem & subj_act_item))
                    insert(subject.SubjectActItem, subj_act_item)
                end
            end
        end
            
    end
    
    %----- Write logging information for *today* for a single animal; specify as pairs e.g. 'received', 1.2, 'weight', 21.4, ...
    function [logs, animal, researcher] = pushDailyInfo(obj, researcherID, animalID, varargin)
      varargin          = AnimalDatabase.checkPairInput(varargin, 'Daily information to set');

      %% Setup data source
      [gid, researcher, isNew, index]     ...
                        = obj.openDailyLogs(researcherID, animalID);
      database          = researcher.wateringLogs;
      where             = ['daily logs for ' animalID];
      template          = obj.tmplDailyInfo;
      dataRow           = 2;      % right after header
      
      if ~isstruct(researcher.animals)
        obj.pullAnimalList(researcherID);
        researcher      = obj.findResearcher(researcherID);
      end
      animal            = researcher.animals(strcmpi({researcher.animals.ID}, animalID));
      
      %% Create a new sheet if necessary
      if isNew
        [logs, gid]     = obj.copyTemplateInfo(template, 1, database, gid, where, researcher.Name);
      
        %% Overview information
        overview          = { 'Experimenter'            , researcher.Name                                     ...
                            ; 'Principle Investigator'  , researcher.PI                                       ...
                            ; 'Protocol'                , researcher.Protocol                                 ...
                            ; 'Last animal addition'    , datestr(now(), AnimalDatabase.DATE_DISPLAY)       ...
                            ; ''                        , ''                                                  ...
                            ; 'This spreadsheet is generated and maintained by a program, please do not edit.', ''  ...
                            ; 'Logs for individual mice are in the sheets corresponding to their names.'      , ''  ...
                            };
        try
          mat2sheets(database, AnimalDatabase.FIRST_SHEET, [1,1], overview, 'Overview');
        catch err
          displayException(err);
          error('AnimalDatabase:pullDailyLogs', 'Failed to create overview sheet in %s for %s.', where, researcher.Name);
        end
        
      else
        data              = obj.readFromDatabase(database, gid, where, researcher.Name);
        logs              = obj.parseFromDatabase(template, dataRow, data, gid, where, researcher.Name);
      end

      
      %% Find the location at which to output information for today
      % N.B. TODO This doesn't handle going over the edge of midnight... we assume behavior is run
      % in normal hours only (for now)
      dates             = arrayfun(@(x) datenum(x.date), logs);
      thisDate          = floor(now());
      if isempty(dates)
        relDays         = 1;
      else
        relDays         = thisDate - dates(end);
      end
      if relDays > 1
        if AnimalDatabase.ALLOW_RECORDS_LAPSE
          complainFcn   = @warning;
        else
          complainFcn   = @error;
        end
        complainFcn('AnimalDatabase:pushDailyInfo', '%d days have elapsed since the last time %s (researcher %s) were filled... how can this be?', relDays, where, researcher.Name);
        relDays         = 1;            % in case we're being lax, must write consecutively
      elseif relDays < 0
        error('AnimalDatabase:pushDailyInfo', 'The last time %s (researcher %s) were filled is %d days in the future... has somebody discovered time travel?', where, researcher.Name, -relDays);
      end
      dataRow           = numel(logs) + relDays;
      
      %% Add a row for today if necessary
      if relDays > 0
        for iField = 1:numel(template)
          logs(dataRow).(template(iField).identifier)       ...
                        = obj.emptyForFormat(template(iField).data);
        end
      end
      
      %% Update the specified information
      logs(dataRow).date= datevec(thisDate);
      logs(dataRow).date(4:end)         = [];
      for iArg = 1:2:numel(varargin)-1
        if ~ischar(varargin{iArg})
          error('AnimalDatabase:pushDailyInfo', 'Identifiers to set must be strings.');
        end
        if ~isfield(logs, varargin{iArg})
          error('AnimalDatabase:pushDailyInfo', 'Invalid identifier %s for data to set.', varargin{iArg});
        end
        logs(dataRow).(varargin{iArg})  = varargin{iArg+1};
      end
  
      %% Write the entire row in string format
      obj.writeDatabaseRow(logs(dataRow), template, dataRow+1, database, gid, where, researcher.Name);
      
        
      %% Construct "right now" summary info and store in the animal listing; must include date stamp
      filledLog         = obj.suggestValues(template, logs(dataRow), {obj.whatIsThePlan(animal,false)});
      summary           = cellfun(@(x) filledLog.(x), {obj.tmplRightNow.data}, 'UniformOutput', false);
      % Assume that all array data are either dates or times, otherwise they're not allowed
      isDate            = cellfun(@(x) isnumeric(x) && numel(x)==3, summary);
      summary(isDate)   = cellfun(@AnimalDatabase.datenum2date, summary(isDate), 'UniformOutput', false);
      isTime            = cellfun(@(x) isnumeric(x) && numel(x)==2, summary);
      summary(isTime)   = cellfun(@AnimalDatabase.datenum2time, summary(isTime), 'UniformOutput', false);
      
      if any(cellfun(@(x) isnumeric(x) && numel(x)>1, summary))
        error('AnimalDatabase:pushDailyInfo', 'Invalid contents of rightNow struct, numeric arrays are not supported.');
      end
      summary           = cell2struct(summary, {obj.tmplRightNow.data}, 2);
%       summary.date      = AnimalDatabase.datenum2date(datevec(thisDate));
      % Special case for weight -- always ensure a valid value from the last known weighing
      if isempty(summary.weight)
        iAvailable      = find(~cellfun(@isempty, {logs.weight}), 1, 'last');
        if isempty(iAvailable)
          summary.weight= animal.initWeight;
        else
          summary.weight= logs(iAvailable).weight;
        end
      end

      [animal,researcher] = obj.pushAnimalInfo(researcherID, animalID, 'rightNow', summary);
      
      % insert weighing information
      log_date = sprintf('%d-%02d-%02d', filledLog.date(1), filledLog.date(2), filledLog.date(3));
      if ~isempty(filledLog.weight)
        weighing = struct( ...
            'user_id', researcherID, ...
            'subject_id', animalID, ...
            'weighing_time', datestr(now, 'yyyy-mm-dd HH:MM:ss'), ...
            'weight', filledLog.weight ...
            );
        
        if ~isempty(filledLog.weighLocation)
            loc.location = filledLog.weighLocation;
            inserti(lab.Location, loc)
            weighing.location = loc.location;
        end
        
        if ~isempty(filledLog.weighPerson)
            user.user_id = filledLog.weighPerson;
            inserti(lab.User, user)
            weighing.weigh_person = user.user_id;
        end
        insert(action.Weighing, weighing)
      end
      
      
      % insert water administration information
      water_info_key = struct( ...
        'user_id', researcherID, ...
        'subject_id', animalID, ...
        'administration_date', log_date...
        );
      water_info = water_info_key;
      water_info.watertype_name = 'Unknown';
      
      if ~isempty(filledLog.earned)
         water_info.earned = filledLog.earned;
      end
      if ~isempty(filledLog.received)
         water_info.received = filledLog.received;
      end
      if ~isempty(filledLog.supplement)
         water_info.supplement = filledLog.supplement;
      end
      
      if isempty(fetch(action.WaterAdministration & water_info_key))
          insert(action.WaterAdministration, water_info)
      else
          if ~isempty(filledLog.earned)
              update(action.WaterAdministration & water_info_key, 'earned', water_info.earned)
          else
              update(action.WaterAdministration & water_info_key, 'earned')
          end
          if ~isempty(filledLog.received)
              update(action.WaterAdministration & water_info_key, 'received', water_info.received)
          else
              update(action.WaterAdministration & water_info_key, 'received')
          end
          if ~isempty(filledLog.supplement)
              update(action.WaterAdministration & water_info_key, 'supplement', water_info.supplement)
          else
              update(action.WaterAdministration & water_info_key, 'supplement')
          end
      end
      
      % insert subject health status information
      health_status_key = struct( ...
        'user_id', researcherID, ...
        'subject_id', animalID, ...
        'status_date', log_date...
        );
    
      health_status = health_status_key;
       
      normal = filledLog.normal.char;
      if strcmp(normal, 'Yes')
          health_status.normal_behavior = 1;
      else
          health_status.normal_behavior = 0;
      end
      health_status.bcs = filledLog.bcs;
      health_status.activity = filledLog.activity;
      health_status.posture_grooming = filledLog.posture;
      health_status.eat_drink = filledLog.eatDrink;
      health_status.turgor = filledLog.turgor;
      
      if ~isempty(filledLog.comments)
          health_status.comments = filledLog.comments;
      end
      
      if isempty(fetch(subject.HealthStatus & health_status_key))
          insert(subject.HealthStatus, health_status)
      else
          update(subject.HealthStatus & health_status_key, 'normal_behavior', health_status.normal_behavior)
          update(subject.HealthStatus & health_status_key, 'bcs', health_status.bcs)
          update(subject.HealthStatus & health_status_key, 'activity', health_status.activity)
          update(subject.HealthStatus & health_status_key, 'posture_grooming', health_status.posture_grooming)
          update(subject.HealthStatus & health_status_key, 'eat_drink', health_status.eat_drink)
          update(subject.HealthStatus & health_status_key, 'turgor', health_status.turgor)
          if ~isempty(filledLog.comments)
              update(subject.HealthStatus & health_status_key, 'comments', health_status.comments)
          else
              update(subject.HealthStatus & health_status_key, 'comments')
          end
      end
      
      % insert action item
      if ~isempty(filledLog.actions)
          action_item = struct(...
              'user_id', researcherID, ...
              'subject_id', animalID, ...
              'action_date', log_date ...
              );
          for iaction = 1:length(filledLog.actions)
              action_item.action_id = iaction;
              action_item_key = action_item;
              if isempty(fetch(action.ActionItem & action_item_key))
                  action_item.action = filledLog.actions{iaction};
                  insert(action.ActionItem, action_item)
              end
          end
      end
      
      % ingest session
        if ~isnan(filledLog.trainStart) && ~isempty(filledLog.mainMazeID) % TODO: ingest trainings without mainMazeID
            session = struct(...
              'user_id', researcherID, ...
              'subject_id', animalID, ...
              'session_date', log_date ...
              );
            
            if isempty(acquisition.Session & session_date)
                session.session_number = 1;
            else
                number = fetchn(acquisition.Session & session_date, 'session_number');
                session.session_number = max(number) + 1;
            end
            
            session.session_start_time = [log_date, springf(' %2d:%2d:00', ...
                filledLog.trainStart(1), filledLog.trainStart(2))];
            session.session_end_time = [log_date, sprintf(' %2d:%2d:00', ...
                log.trainEnd(1), log.trainEnd(2))];
            
            % ingest location
            key_location.location = filledLog.rigName;
            inserti(lab.Location, key_location)

            session.location = filledLog.rigName;
            session.user_id = researcherID;
            session.task = 'Towers';
            session.level = filledLog.mainMazeID;
            session.set_id = 1;
            session.stimulus_bank = filledLog.stimulusBank;
            session.stimulus_set = filledLog.stimulusSet;
            session.ball_squal = filledLog.squal;
            session.session_performance = filledLog.performance;

            insert(acquisition.Session, session)
        end
      
      
    end
    
    %----- Write one column of animal-specific information for multiple *existing* animals
    function pushBatchInfo(obj, researcherID, animalIDs, identifier, value)
      %% Setup data source
      database          = AnimalDatabase.DATABASE_ID;
      where             = 'animal information';
      [gid, researcher, isNew, index]     ...
                        = obj.openAnimalList(researcherID);
      if isNew
        template        = obj.tmplAnimal;
        [list, gid]     = obj.copyTemplateInfo(template, 1, database, gid, where, researcher.Name);
        obj.Researchers(index).animalsGID = gid;
        researcher      = obj.Researchers(index);
      else
        [list,~,template] = obj.pullAnimalList(researcherID);
      end
      
      %% Find the location at which to output information 
      dataRow           = cellfun(@(x) find(strcmpi(x,{list.ID})), animalIDs, 'UniformOutput', false);
      if any(cellfun(@isempty, dataRow))
        error('AnimalDatabase:pushBatchInfo', 'Animal(s) not found in database for researcher %s: %s', researcherID, strjoin(animalIDs(cellfun(@isempty, dataRow)), ', '));
      end
      dataRow           = [dataRow{:}];
      
      dataCol           = find(strcmp({template.identifier}, identifier));
      if numel(dataCol) ~= 1
        error('AnimalDatabase:pushBatchInfo', 'Invalid field %s to write.', identifier);
      end
      template          = template(dataCol);
      
      %% Retrieve the column to be written, and update rows for target animals
      data              = {list.(template.identifier)};
      if iscell(value)
        data(dataRow)   = value;
      else
        [data{dataRow}] = deal(value);
      end
      
      %% Write the entire column in string format
      obj.writeDatabaseCol(data, template, dataCol, database, gid, where, researcher.Name);

    end

    
    %----- Display a GUI for viewing and interacting with the database plus daily information
    function gui(obj, personID)
      if nargin < 2
        personID      = [];
      end
      
      %% Layout the GUI display
      obj.layoutGUI();
      obj.layoutResponsibles(personID);
      set(obj.figGUI, 'Visible', 'on');

      %% Always show researchers their own animals
      if any(strcmpi(personID, {obj.Researchers.ID}))
        obj.nextInLine([], [], personID);
      else
        obj.nextInLine([], []);
      end
      
      %% Setup timers
      obj.setupUpdateTimer();
    end
    
    %----- Close the GUI figure and stop live updates
    function closeGUI(obj, handle, event)
      if ~isempty(obj.tmrRightNow) && isvalid(obj.tmrRightNow)
        stop(obj.tmrRightNow);
        delete(obj.tmrRightNow);
      end
      
      if ~isempty(obj.tmrPollScale) && isvalid(obj.tmrPollScale)
        stop(obj.tmrPollScale);
        delete(obj.tmrPollScale);
      end
      
      if ishghandle(obj.figGUI)
        delete(obj.figGUI);
      end
      
      if ishghandle(obj.figCheckout)
        delete(obj.figCheckout);
      end
      
      obj.figGUI              = gobjects(0);
      obj.figCheckout         = gobjects(0);
      obj.tmrRightNow         = [];
      obj.tmrPollScale        = [];

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
    
    %----- Close the checkout GUI, returning to the main if appropriate
    function closeCheckoutGUI(obj, handle, event, personID, forFinalize)
      %% Special case where everything has been closed
      if ishghandle(obj.figCheckout)
        delete(obj.figCheckout);
      end
      if ~ishghandle(obj.figGUI) || ~forFinalize
        return;
      end
      
      obj.figCheckout         = gobjects(0);
      
      %% Go back to checking for finalization
      obj.areWeThereYet([], [], personID, false);
    end
    
    %----- Close the performance GUI
    function closePerformanceGUI(obj, handle, event)
      if ishghandle(obj.figPerform)
        delete(obj.figPerform);
      end
      
      obj.figPerform          = gobjects(0);
    end
    
    
    %----- Check that the update timer is running, otherwise restart it
    function checkUpdateTimer(obj, handle, event, doTrigger)
      if nargin < 4 || isempty(doTrigger)
        doTrigger             = false;
      end
      
      if isempty(obj.tmrRightNow)
        obj.setupUpdateTimer();
      elseif ~isvalid(obj.tmrRightNow)
        warning('AnimalDatabase:checkUpdateTimer', 'Live update timer is invalid, restarting now.');
        obj.setupUpdateTimer();
      elseif ~strcmpi(get(obj.tmrRightNow,'Running'), 'on')
        warning('AnimalDatabase:checkUpdateTimer', 'Live update timer seems to have stopped, restarting now.');
        obj.setupUpdateTimer();
      elseif doTrigger
        executeCallback(obj.tmrRightNow, 'TimerFcn', [], true);
      end
      
      % also check database-independent timers
      manageNotificationTimers('check',obj);
    end
    
    %----- Callback whenever the live update timer is stopped
    function stopUpdateTimer(obj, handle, event)
      if ishghandle(obj.btn.finalize)
        set(obj.btn.finalize, 'BackgroundColor', HandlingStatus.color(HandlingStatus.Dead));
      end
      delete(handle);
      obj.tmrRightNow         = [];
    end
    
    %----- Refresh animal list with "right now" info
    function updateAnimalSummary(obj, handle, event, ignoreBusy)
      %% Don't run timer function if busy or no GUI exists
      if obj.imBusy && (nargin < 4 || ~ignoreBusy)
        return;
      end
      if ~ishghandle(obj.figGUI)
        return;
      end
      
      %% Run this in a try-catch block so that errors are more noticeable
      try

      %% Set timestamp if we have a valid update state
      thisDate                = AnimalDatabase.datenum2date();
      timeStamp               = datestr(now(), AnimalDatabase.DATE_DISPLAY);
      if ~obj.imBusy
        set(obj.btn.finalize, 'String', ['FINALIZE    ' timeStamp], 'BackgroundColor', AnimalDatabase.CLR_NOTSELECTED);
      end
      if isfield(obj.btn,'signOff') && ~isempty(obj.btn.signOff) && ishghandle(obj.btn.signOff)
        set( obj.btn.signOff, 'String', ['FINALIZE    ' timeStamp]);
      end
      obj.imBusy              = true;
      
      
      %% Get animal lists for all displayed researchers
      researcherID            = arrayfun(@(x) get(x,'UserData'), obj.btn.showWhose, 'UniformOutput', false);
      try
        animals               = obj.pullAnimalList(researcherID);
      catch err
        set(obj.btn.finalize, 'BackgroundColor', EntryState.color(EntryState.Invalid));
        return;
      end
      
      %% Show summary for all displayed researchers
      for iID = 1:numel(animals)
        %% Count the number of weighed / active animals
        [doCare,~,animal]     = obj.shouldICare(animals{iID}, get(obj.btn.responsible,'UserData'), false, true);
        active                = animal(doCare);
        emergency             = animal( [animal.status] == HandlingStatus.Missing | [animal.status] == HandlingStatus.Unknown );
        nWeighed              = sum(AnimalDatabase.takenCaredOf(active, thisDate));
        
        %% Show colored text according to whether all animals have been weighed
        if nWeighed == numel(active) && isempty(emergency)
          color               = AnimalDatabase.CLR_ALLSWELL;
        else
          color               = AnimalDatabase.CLR_ALERT;
        end
        
        info                  = sprintf('%d / %d', nWeighed, numel(active));
        if ~isempty(emergency)
          info                = sprintf('%s (%d!)', info, numel(emergency));
        end
        info                  = sprintf('<div style="color:rgb(%d,%d,%d)">%s</div>', color(1)*255, color(2)*255, color(3)*255, info);
        info                  = sprintf('%s<br/>%s', researcherID{iID}, info);
        set(obj.btn.showWhose(iID), 'String', ['<html><div style="text-align:center">' info '</div></html>']);
      end
      
      
      %% Provide more details for the currently displayed researcher and his/her animal list
      iResearcher             = find( arrayfun(@(x) get(x,'Value'), obj.btn.showWhose) == 1 );
      if numel(iResearcher) ~= 1 || isempty(obj.btn.aniInfo)
        return;
      end
      animal                  = animals{iResearcher};
      [doCare,techDuty,animal]= obj.shouldICare(animal, get(obj.btn.responsible,'UserData'), false, true);
      animalID                = arrayfun(@(x) get(x,'UserData'), obj.btn.aniInfo, 'UniformOutput', false);
      animalID                = cellfun(@(x) x{1}, animalID, 'UniformOutput', false);
      
      %% Flag the GUI display as needing to be (manually) refreshed if there are discrepancies with what's shown
      btnWho                  = obj.btn.showWhose(iResearcher);
      if isempty(setxor(animalID, {animal.ID}))
        if isempty(btnWho) || ~ishghandle(btnWho)
          keyboard
        end
        AnimalDatabase.setBorderByState(btnWho, [1 1 1]*0.6, 1);
      else
        description           = regexp(get(btnWho,'String'), AnimalDatabase.RGX_HTMLBODY, 'tokens', 'once');
        description           = strrep(description{:}, 'style="', 'style="font-size:95%; ');
        set (  btnWho                                                                                                 ...
            , 'String'  , ['<html><div style="color:red; font-weight:bold">OUT OF SYNC</div>' description '</html>']  ...
            , 'TooltipString' , 'Animal list has changed w.r.t. the database, you must click to refresh!'             ...
            );
        AnimalDatabase.setBorderByState(btnWho, AnimalDatabase.CLR_ALERT);
      end
      if isempty(animalID)
        return;
      end
      
      %% Loop through animals currently in GUI to update; remote additions/deletions will be flagged
      emptyLog                = AnimalDatabase.emptyLike(obj.tmplDailyInfo, {''});
      for iAni = 1:numel(obj.btn.aniInfo)
        %% Retrieve update info from animal listing, if available
        animalID              = get(obj.btn.aniInfo(iAni),'UserData');
        animalID              = animalID{1};
        index                 = find(strcmpi({animal.ID}, animalID));
        if isempty(index) || isempty(animal(index).status) || animal(index).status >= HandlingStatus.AdLibWater
          continue;
        end
        rightNow              = animal(index).rightNow;
        
        %% Generate default values if instantaneous information is not available
        if isempty(rightNow) || rightNow.date ~= thisDate
          fakeLog             = obj.suggestValues(obj.tmplDailyInfo, emptyLog, {animal(index)});
          rightNow            = cellfun(@(x) fakeLog.(x), {obj.tmplRightNow.data}, 'UniformOutput', false);
          rightNow            = cell2struct(rightNow, {obj.tmplRightNow.data}, 2);
        end
        
        %% Format button text to display a set of information specified here
        info                  = repmat({''}, 1,4);
        info{1}               = animalID;
        if doCare(index)
          info{1}             = ['<font color="blue"><b>' info{1} '</b></font>'];
        end
        info{1}               = ['<div>' info{1} '</div>'];

        %% Training time start, or end and performance
        if isfinite(rightNow.trainEnd)
          info{2}             = obj.applyFormat(rightNow.trainEnd, AnimalDatabase.SPECS_TIME);
          info{2}             = sprintf('%s (%.3g%%)', info{2}, rightNow.performance);
          info{2}             = ['<font color="green">' info{2} '</font>'];
        elseif isfinite(rightNow.trainStart)
          info{2}             = obj.applyFormat(rightNow.trainStart, AnimalDatabase.SPECS_TIME);
          info{2}             = ['@ <font color="purple">' info{2} '</font>'];
        elseif doCare(index)
          info{2}             = ['<font color="blue">' char(techDuty(index)) '</font>'];
        else
          info{2}             = char(techDuty(index));
        end
        info{2}               = ['<div style="font-size:95%">' info{2} '</div>'];

        %% Amount of water obtained and required as a supplement
        info{3}               = sprintf('%.3g / %.3g mL', rightNow.earned, animal(index).waterPerDay);
        info{3}               = ['<div style="font-size:95%">' info{3} '</div>'];

        if isfinite(rightNow.received)
          info{4}             = '&nbsp;';                     % already weighed, no action neccessary
          color               = [0 0 0];
        elseif rightNow.supplement > 0
          info{4}             = sprintf('%.3g mL', rightNow.supplement);
          color               = AnimalDatabase.CLR_ALERT;
        elseif isfinite(rightNow.supplement)
          info{4}             = '0';
          color               = AnimalDatabase.CLR_ALLSWELL;
        else
          info{4}             = sprintf('%.3g mL', animal(index).waterPerDay);
          color               = AnimalDatabase.CLR_ALERT;
        end
        info{4}               = sprintf('<div style="color:rgb(%d,%d,%d)">%s</div>', color(1)*255, color(2)*255, color(3)*255, info{4});
        
        %% Concatenate and show button title
        blurb                 = ['<html><div style="text-align:center">' strjoin(info) '</div></html>'];
        set(obj.btn.aniInfo(iAni), 'String', blurb);
      end
      
      catch err
        obj.imBusy            = false;
        displayException(err);
%         keyboard
      end
      
      obj.imBusy              = false;
    end
    
    
    %----- Show details for the next animal that needs attention (e.g. needs watering)
    function didSomething = nextInLine(obj, handle, event, researcherID)

      %% Default arguments
      if ~ishghandle(obj.figGUI)
        if nargout > 0
          error('AnimalDatabase:nextInLine', 'The GUI is not running.');
        end
        return;
      end
      if nargin < 4
        researcherID          = [];
      end
      
      thisDate                = AnimalDatabase.datenum2date();
      didSomething            = true;
      personID                = get(obj.btn.responsible, 'UserData');
      alreadyBusy             = obj.waitImWorking();

      %% Decide on order in which to go through researchers
      btnOwner                = obj.btn.showWhose;
      iFallback               = [];
      if isempty(researcherID)
        %% Prefer currently selected researcher if available
        iCurrent              = find(arrayfun(@(x) get(x,'Value')==1, btnOwner), 1, 'first');
        if isempty(iCurrent)
          iCurrent            = 1;
        end
        btnOwner              = btnOwner([iCurrent:end, 1:iCurrent-1]);
        researcherID          = get(btnOwner, 'UserData');
      elseif iscell(researcherID)
        %% A specific list was given
        [~,iOrder]            = ismember(lower(get(btnOwner,'UserData')), lower(researcherID));
        btnOwner              = btnOwner(iOrder);
      else
        %% For one specific person, flag that we should default to showing their list
        iFallback             = find(strcmpi(get(obj.btn.showWhose,'UserData'), researcherID), 1, 'first');
        if isempty(iFallback)
          iFallback           = 1;
        end
        btnOwner              = btnOwner([iFallback:end, 1:iFallback-1]);
        iFallback             = 1;
        researcherID          = get(btnOwner, 'UserData');
      end
      if ~iscell(researcherID)
        researcherID          = {researcherID};
      end
      
      
      %% Loop through researchers sequentially
      for iID = 1:numel(researcherID)
        %% See if there are any animals on the should-care list
        animals               = obj.pullAnimalList(researcherID{iID});
        [doCare,~,animals]    = obj.shouldICare(animals, personID);
        if all(AnimalDatabase.takenCaredOf(animals(doCare), thisDate))
          continue;
        end
        
        
        %% Make sure that we're displaying an up-to-date animal list
        if get(btnOwner(iID), 'Value') ~= 1
          executeCallback(btnOwner(iID), [], [], false);
        end

        while true
          drawnow;
          btnAni              = obj.btn.aniInfo;
          animalID            = cellfun(@(x) x{1}, get(btnAni, 'UserData'), 'UniformOutput', false);
          if isempty(setxor({animals.ID}, animalID))
            break;
          end
          % Somehow we're out of sync so refresh everything
          executeCallback(btnOwner, [], [], false);
          [doCare,~,animals]  = obj.shouldICare(obj.pullAnimalList(researcherID{iID}), personID);
        end
        
        %% Get a preferred order of animals to go through
        iCurrent              = find(arrayfun(@(x) get(x,'Value'), btnAni));
        if isempty(iCurrent)
          iCurrent            = 1;
        end
        animalID              = animalID([iCurrent:end, 1:iCurrent-1]);
        btnAni                = btnAni([iCurrent:end, 1:iCurrent-1]);
        animals               = animals(doCare);
        [sel,iOrder]          = ismember(lower(animalID), lower({animals.ID}));
        animals               = animals(iOrder(sel));
        btnAni                = btnAni(sel);

        %% Focus on the first animal that has not received water
        iAttendToMe           = find(~AnimalDatabase.takenCaredOf(animals,thisDate), 1, 'first');
        if isempty(iAttendToMe)
          error('AnimalDatabase:nextInLine', 'It should be impossible not to find an animal that needs attention at this point.');
        end
        executeCallback(btnAni(iAttendToMe));
        obj.okImDone(alreadyBusy);
        return;
      end
      
      
      %% Clear the animal display to indicate that there is nothing to show
      didSomething            = false;
      delete(get(obj.tbl.aniID   , 'Children'));
      delete(get(obj.tbl.aniData , 'Children'));
      delete(get(obj.tbl.aniDaily, 'Children'));

      obj.axs.aniImage.clearCanvas();
      set(obj.axs.aniImage, 'Visible', 'off');
      set(obj.cnt.dailyScroll, 'MinimumHeights', 1);
      set(obj.cnt.dataScroll , 'MinimumHeights', 1);
      if isfield(obj.cnt, 'groupScroll')
        set(obj.cnt.groupScroll, 'MinimumHeights', 1);
      end
      if isfield(obj.btn, 'aniInfo')
        set(obj.btn.aniInfo(ishghandle(obj.btn.aniInfo)), 'Value', 0);
      end
      if isfield(obj.pnl, 'aniGroup')
        set(obj.pnl.aniGroup(ishghandle(obj.pnl.aniGroup)), 'HighlightColor', [1 1 1], 'ShadowColor', [1 1 1]*0.7, 'BorderWidth', 1);
      end
      
      if ~isempty(iFallback)
        executeCallback(btnOwner(iFallback), [], [], false);
      end
      
      obj.okImDone(alreadyBusy);
      
    end
    
  end
  
end
