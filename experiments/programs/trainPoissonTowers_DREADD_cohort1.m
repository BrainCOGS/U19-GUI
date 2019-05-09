function regiment = trainPoissonTowers_DREADD_cohort1(varargin)
 
  regiment  = runCohortExperiment ( 'C:\Data\badura\PoissonTowers1'   ... dataPath
                                  , 'Poisson towers'                  ... experName
                                  , 'DREADD_cohort1'                  ... cohortName
                                  , varargin{:}                       ...
                                  );
    
end
