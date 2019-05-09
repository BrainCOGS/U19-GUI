function regiment = trainPoissonBlocks_sak_Ai93cohort4(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonBlocksAi93_4'      ... dataPath
                                  , 'Poisson Blocks'                          ... experName
                                  , 'Ai93cohort4'                             ... cohortName
                                  , numDataSync                               ... numDataSync
                                  , varargin{:}                               ...
                                  );
    
end
