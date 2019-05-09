function regiment = trainTargetPursuit(varargin)
 
  regiment  = runCohortExperiment ( 'C:\Data\sakoay\TargetPursuit1'   ... dataPath
                                  , 'Target Pursuit'                  ... experName
                                  , 'cohort1'                         ... cohortName
                                  , varargin{:}                       ...
                                  );

end
