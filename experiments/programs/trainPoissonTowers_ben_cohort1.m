function regiment = trainPoissonTowers_ben_cohort1(varargin)

  regiment  = runCohortExperiment ( 'C:\Data\ben\PoissonTowers1'   ... dataPath
                                  , 'Poisson Towers'                  ... experName
                                  , 'cohort1'                         ... cohortName
                                  , varargin{:}                       ...
                                  );
    
end
