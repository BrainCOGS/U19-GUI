function regiment = trainPoissonTowers_DREADD_cohort2(varargin)
 
  regiment  = runCohortExperiment ( 'C:\Data\badura\PoissonTowers2'   ... dataPath
                                  , 'Poisson Towers'                  ... experName
                                  , 'DREADD_cohort2'                  ... cohortName
                                  , varargin{:}                       ...
                                  );
    
end
