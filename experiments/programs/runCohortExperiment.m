%% Load GUI for training animals
function regiment = runCohortExperiment(dataPath, experName, cohortName, numDataSync, loadOnly, fcnOnClose)

  % Default arguments
  if nargin < 4
    numDataSync = [];
  end
  if nargin < 5 || isempty(loadOnly)
    loadOnly    = false;
  end
  if nargin < 6
    fcnOnClose  = [];
  end
  if loadOnly > 1
    fastLoad    = TrainingRegiment.fastLoad();
    TrainingRegiment.fastLoad(true);
  end
  
  
  % Make sure to randomize the random number sequence!
  rng('shuffle');

  % Default to ViRMEn experiment directory
  cd([parsePath(mfilename('fullpath')) filesep '..']);

  % Load training schedule
  vr.regiment   = TrainingRegiment( experName                     ...
                                  , [ dataPath filesep            ...
                                      strrep(experName,' ','')    ...
                                      '_'                         ...
                                      cohortName '_'              ...
                                      RigParameters.rig           ...
                                      '.mat'                      ...
                                    ]                             ...
                                  , '', numDataSync               ...
                                  );
  vr.regiment.sort();   % Alphabetical order of animals
  regiment      = vr.regiment;
  
  if loadOnly > 1
    TrainingRegiment.fastLoad(fastLoad);
  end
  if loadOnly
    return;
  end
  
  
  % Ask user to select an animal
  vr.regiment.guiSelectAnimal({'TRAIN', 'Training'}, @trainAnimal, @cleanup);
  vr.regiment.selectValveButton();

  
  %% Start training the given animal
  function trainAnimal(info)
    vr.trainee  = info;
  
    % Load experiment of interest
    if ~exist(vr.trainee.experiment, 'file')
      hError    = errordlg( sprintf ( 'Invalid experiment "%s" for animal %s. Please specify it correctly in the schedule.' ...
                                    , vr.trainee.experiment, vr.trainee.name                                                ...
                                    )                                                                                       ...
                          , 'Invalid experiment', 'modal'                                                                   ...
                          );
      uiwait(hError);
      vr.regiment.guiSelectAnimal({'TRAIN', 'Training'}, @trainAnimal, @cleanup);
      return;
    end
    
    % Set custom info 
    load(vr.trainee.experiment);
    exper.userdata                  = vr;
    
    % Always set the display transformation because ViRMEn defaults without warning to some existing
    % transformation in the case of editing the world .mat file on a machine without the previously
    % stored transformation function
    if isprop(RigParameters,'mesoscope')
      if RigParameters.mesoscope
        exper.transformationFunction  = @DomeProjection_cpp;
      else
        if RigParameters.simulationMode || ~RigParameters.hasDAQ
          exper.transformationFunction  = @transformPerspectiveMex;
        else
          exper.transformationFunction  = @transformToroidalParametrizedMex;
        end
      end
    else
      if RigParameters.simulationMode || ~RigParameters.hasDAQ
        exper.transformationFunction  = @transformPerspectiveMex;
      else
        exper.transformationFunction  = @transformToroidalParametrizedMex;
      end
    end
    
    % Special case for simulations
    if RigParameters.simulationMode
%       exper.movementFunction        = @moveArduinoLinearVelocityMEX_simIdeal;
%       exper.movementFunction        = @moveByRecordedData;
      exper.movementFunction        = @moveWithKeyboard;
    elseif RigParameters.hasDAQ
      exper.movementFunction        = MovementSensor.rule(vr.trainee.virmenSensor);
      
    % Special case for testing on laptop
    else
      exper.movementFunction        = @moveWithAutoKeyboard;
      exper.variables.trialEndPauseDuration     = '0.1';
      exper.variables.interTrialCorrectDuration = '0.3';
      exper.variables.interTrialWrongDuration   = '0.3';
    end

    % Archive code if so desired
    if vr.regiment.doStoreCode
      logFile     = vr.regiment.whichLog(vr.trainee);
      [dir,name]  = parsePath(logFile);
      if ~exist(dir, 'dir')
        mkdir(dir);
      end
      
      virmenDir   = parsePath(parsePath(parsePath(which('virmenEngine'))));
      zip(fullfile(dir, [name '.zip']), virmenDir);
    end

    % Run experiment
    status        = exper.run();
    if isstruct(status)
      TrainingRegiment.enableFigureClosing();
      errordlg(status.message, 'ViRMEn runtime error', 'modal');
      rethrow(status);
    end
    
    % Refresh GUI
    vr.regiment.guiSelectAnimal({'TRAIN', 'Training'}, @trainAnimal, @cleanup);
  end


  %% Cleanup 
  function cleanup()
    delete(vr.regiment);
    if ~isempty(fcnOnClose)
      fcnOnClose();
    end
  end

end


