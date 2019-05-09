function regiment = trainPoissonBlocks_sak_GP53cohort1(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonBlocksGP53_1'  ... dataPath
                                  , 'Poisson Blocks'                      ... experName
                                  , 'GP53cohort1'                         ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
