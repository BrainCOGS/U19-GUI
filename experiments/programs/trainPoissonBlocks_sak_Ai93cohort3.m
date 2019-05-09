function regiment = trainPoissonBlocks_sak_Ai93cohort3(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment      = runCohortExperiment ( 'C:\Data\sakoay\PoissonBlocksAi93_3'      ... dataPath
                                      , 'Poisson Blocks'                          ... experName
                                      , 'Ai93cohort3'                             ... cohortName
                                      , numDataSync                               ... numDataSync
                                      , varargin{:}                               ...
                                      );
    
end
