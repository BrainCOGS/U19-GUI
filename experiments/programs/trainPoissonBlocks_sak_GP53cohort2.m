function regiment = trainPoissonBlocks_sak_GP53cohort2(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonBlocksGP53_2'      ... dataPath
                                  , 'Poisson Blocks'                          ... experName
                                  , 'GP53cohort2'                             ... cohortName
                                  , numDataSync                               ... numDataSync
                                  , varargin{:}                               ...
                                  );
    
end
