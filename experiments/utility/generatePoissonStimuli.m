%% GENERATEPOISSONSTIMULI(experimentPath)
%
%   Pre-generates a bank of Poisson stimulus trains for the given
%   experiment configuration. experimentPath should be the ViRMEn .mat file
%   that contains the world configuration. An absolute path is not required
%   if it is in the Matlab path.
%
%   This function returns the stimulus bank, which should be saved in a
%   .mat file of your choice. Note that your experiment code should be
%   configured to load the appropriate object depending on how you named
%   it; in poisson_towers.m the bank is called 'poissonStimuli'.
%
%   Note that for this code to work, it is assumed that you have added 
%       code.setup = @setupTrials;
%   to the main function in your experiment's .m file, where setupTrials()
%   is the function that calls prepareMazes() and so forth to set up
%   parameters for each maze difficulty level. See poisson_towers.m for 
%   example usage.
%
function stimuli = generatePoissonStimuli(experimentPath, protocol, varargin)
  
  % Mnemonics for configuration possibilities
  mnemonic.targetNumTrials    = 'n';
  mnemonic.fracDuplicated     = 'dup';
  mnemonic.trialDuplication   = 'x';
  mnemonic.trialDispersion    = 'dis';
  mnemonic.panSessionTrials   = 'pan';
  
  % Help
  if nargin < 2
    fprintf ( [ '\nUsage:   generatePoissonStimuli(experimentPath, protocol, [numSessionSets = 1], ...)\n\n'  ...
              , 'Additional options can include Name, Value pairs for custom stimuli\n'   ...
              , 'generation options, where Name is any one of:\n'                         ...
              , '    ', strjoin(fieldnames(mnemonic), '\n    ')                           ...
              , '\n\n'                                                                    ...
              ] );
    return;
  end
  
  % Optional: number of sets of stimuli (sessions)
  if ~isempty(varargin) && isnumeric(varargin{1})
    numSets   = varargin{1};
    varargin(1) = [];
  else
    numSets   = 1;
  end
  
  % Alphabetical order of configurations
  config      = struct();
  for iVar = 1:2:numel(varargin)-1
    config.(varargin{iVar})   = varargin{iVar+1};
  end
  config      = orderfields(config);
  

  % Load experiment and maze configuration
  vr          = load(experimentPath);
  code        = vr.exper.experimentCode();
  if nargin > 1
    vr        = code.setup(vr, protocol);
    info      = functions(protocol);
    
    % Generate file name based on protocol and custom parameters (if any)
    target    = ['stimulus_trains_' func2str(protocol)];
    if numSets > 1
      target  = sprintf('%s_%dsets', target, numSets);
    end
    for field = fieldnames(config)'
      if isfield(mnemonic, field{:})
        name  = mnemonic.(field{:});
      else
        error ( 'generatePoissonStimuli:options'                                                        ...
              , '"%s" is not a valid stimulus generation option. You can specify one or more of:  %s'   ...
              , field{:}, strjoin(fieldnames(mnemonic), ' OR ')                                         ...
              );
%         name  = field{:};
      end
      target  = sprintf('%s_%s%.3g', target, name, config.(field{:}));
    end
    target    = fullfile(parsePath(info.file), [strrep(target, '.', 'p'), '.mat']);
    
    if exist(target, 'file')
      fprintf('WARNING:  Target %s already exists!\n', target);
    end
  else
    vr        = code.setup(vr);
  end
  
  % Apply custom parameters
  for field = fieldnames(config)'
    vr.(field{:})                 = config.(field{:});
    vr.exper.variables.(field{:}) = num2str(config.(field{:}));
  end
  
  % Configure stimuli for all maze levels
  stimuli   = vr.stimulusGenerator(vr.targetNumTrials, vr.fracDuplicated, vr.trialDuplication, vr.trialDispersion, vr.panSessionTrials, numSets);
  for mainMaze = 1:numel(vr.mazes)
    mazeID    = [mainMaze, vr.mazes(mainMaze).criteria.warmupMaze];
    for iMaze = mazeID
      [~,lCue,params] = configureMaze(vr, iMaze, mainMaze, false);
      stimuli.configure(lCue, params{:});
    end
  end
  
  % Write to disk if so desired
  if nargin > 1
    fprintf('This should be saved to:\n   %s\n', target);
    yes       = input('Proceed (y/n/postfix)?  ', 's');
    if strcmpi(yes, 'n') || isempty(yes)
      fprintf('Aborted.\n');
    else
      if ~strcmpi(yes, 'y')
        [dir,name,ext]= parsePath(target);
        target        = fullfile(dir, [name '_' yes, ext]);
        fprintf('User-specified target:\n   %s\n', target);
      end
      poissonStimuli  = stimuli;
      save(target, 'poissonStimuli');
      fprintf('Done.\n');
    end
  end
  
end
