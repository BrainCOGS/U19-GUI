function regiment = trainPoissonTowers_ben_cohort1_dt(varargin)

  regiment  = runCohortExperiment ( 'C:\Data\ben\DiscreteTowers1'   ... dataPath
                                  , 'Discrete Towers'                  ... experName
                                  , 'cohort1'                         ... cohortName
                                  , varargin{:}                       ...
                                  );
    
end
