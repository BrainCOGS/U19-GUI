function regiment = trainPoissonTowers_sak_cohort1(varargin)

  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonTowers1'   ... dataPath
                                  , 'Poisson Towers'                  ... experName
                                  , 'cohort1'                         ... cohortName
                                  , varargin{:}                       ...
                                  );
    
end
