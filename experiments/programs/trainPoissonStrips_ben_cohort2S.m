function regiment = trainPoissonStrips_ben_cohort2S(varargin)

  regiment  = runCohortExperiment ( 'C:\Data\ben\PoissonStrips1'   ... dataPath
                                  , 'Poisson Strips'                  ... experName
                                  , 'cohort2S'                         ... cohortName
                                  , varargin{:}                       ...
                                  );
    
end
