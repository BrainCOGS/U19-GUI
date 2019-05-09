function regiment = trainPoissonBlocks_sak_M2cohort1(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonBlocksM2_1'        ... dataPath
                                  , 'Poisson Blocks'                          ... experName
                                  , 'M2cohort1'                               ... cohortName
                                  , numDataSync                               ... numDataSync
                                  , varargin{:}                               ...
                                  );
    
end
