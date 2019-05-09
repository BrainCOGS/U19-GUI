function regiment = trainPoissonBlocks_sak_GP53cohort5(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonBlocksGP53_5'      ... dataPath
                                  , 'Poisson Blocks'                          ... experName
                                  , 'GP53cohort5'                             ... cohortName
                                  , numDataSync                               ... numDataSync
                                  , varargin{:}                               ...
                                  );
    
end
