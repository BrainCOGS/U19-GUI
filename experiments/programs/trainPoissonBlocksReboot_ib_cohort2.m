function regiment = trainPoissonBlocksReboot_ib_cohort2(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\ibusack\PoissonBlocksReboot'   ... dataPath
                                  , 'Poisson Blocks'                     ... experName
                                  , 'cohort2'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
