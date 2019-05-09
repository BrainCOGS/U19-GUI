function regiment = trainPoissonTowers_sak_GP53cohort1(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonTowersGP53_1'  ... dataPath
                                  , 'Poisson Towers'                      ... experName
                                  , 'GP53cohort1'                         ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
