function regiment = trainPoissonTowers_ben_cohort2(varargin)

  regiment  = runCohortExperiment ( 'C:\Data\ben\PoissonTowers2'   ... dataPath
                                  , 'Poisson Towers'                  ... experName
                                  , 'cohort2'                         ... cohortName
                                  , varargin{:}                       ...
                                  );
    
end
