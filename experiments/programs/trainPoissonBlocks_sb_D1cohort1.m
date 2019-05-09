function regiment = trainPoissonBlocks_sb_D1cohort1(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\sbolkan\PoissonBlocksD1_1'      ... dataPath
                                  , 'Poisson Blocks'                          ... experName
                                  , 'D1cohort1'                             ... cohortName
                                  , numDataSync                               ... numDataSync
                                  , varargin{:}                               ...
                                  );
    
end
