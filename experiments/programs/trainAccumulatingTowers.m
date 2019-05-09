function trainAccumulatingTowers(allowRemoteControl)

  % Make sure to randomize the random number sequence!
  rng('shuffle');

  % Default to ViRMEn experiment directory
  cd([parsePath(mfilename('fullpath')) filesep '..']);

  % Load training schedule
  dataPath        = 'C:\Data\sakoay\AccumTowers1';
  vr.regiment     = TrainingRegiment( 'Accumulating towers'     ...
                                    , [ dataPath filesep        ...
                                        'acctowers_cohort1_'    ...
                                        RigParameters.rig       ...
                                        '.mat'                  ...
                                      ]                         ...
                                    );
  firstCall       = true;
  vr.regiment.sort();   % Alphabetical order of animals
  
  
  % Support remote control
  if nargin < 1
    allowRemoteControl  = false;
  end
  if allowRemoteControl
    vr.pager      = IPPager;
    registerBehavioralEncodings(vr.pager);
  else
    vr.pager      = [];
  end
  
  
  while true
    % Ask user to select an animal
    vr.trainee    = vr.regiment.guiSelectAnimal('TRAIN', 'Training', firstCall, vr.pager);
    firstCall     = false;
    if isempty(vr.trainee)
      vr.regiment.closeGUI();
      break;
    end


    % Load experiment of interest
    if ~exist(vr.trainee.experiment, 'file')
      errordlg( sprintf ( 'Invalid experiment "%s" for animal %s. Please specify it correctly in the schedule.' ...
                        , vr.trainee.experiment, vr.trainee.name                                                ...
                        )                                                                                       ...
              , 'Invalid experiment', 'modal'                                                                   ...
              );
      break;
    end
    load(vr.trainee.experiment);

    % Set custom info 
    exper.userdata                  = vr;

    % Special case for testing on laptop
    if ~RigParameters.hasDAQ
%       exper.movementFunction        = @movePointer;
      exper.movementFunction        = @moveWithAutoKeyboard;
%       exper.movementFunction        = @moveRandomly;
      exper.transformationFunction  = @transformPerspectiveMex;
      exper.variables.trialEndPauseDuration     = '0.1';
      exper.variables.interTrialCorrectDuration = '0.3';
      exper.variables.interTrialWrongDuration   = '0.3';
    end
    
    % HACK -- for testing only
    if allowRemoteControl
      exper.movementFunction        = @moveRandomly;
    end


    % Run experiment
    error         = exper.run();
    if isstruct(error)
      errordlg(error.message, 'ViRMEn runtime error', 'modal');
      rethrow(error);
    end
  end
  
  if allowRemoteControl
    delete(vr.pager);
  end
    
end
