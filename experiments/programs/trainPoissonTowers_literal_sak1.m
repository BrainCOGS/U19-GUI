function regiment = trainPoissonTowers_literal_sak1(varargin)
 
  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonTowersLiteral1'  ... dataPath
                                  , 'Poisson Towers'                        ... experName
                                  , 'cohort1'                               ... cohortName
                                  , varargin{:}                             ...
                                  );
    
end
