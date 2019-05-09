function regiment = trainPoissonTowers_sak_cohortI2(numDataSync, varargin)

  if nargin < 1
    numDataSync = 0;
  end

  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonTowersI2'  ... dataPath
                                  , 'Poisson Towers'                  ... experName
                                  , 'cohortI2'                        ... cohortName
                                  , numDataSync                       ... numDataSync
                                  , varargin{:}                       ...
                                  );
    
end
