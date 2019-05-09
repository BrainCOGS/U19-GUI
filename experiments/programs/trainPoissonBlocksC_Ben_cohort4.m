function regiment = trainPoissonBlocksC_Ben_cohort4(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\Ben\PoissonBlocksC2'  ... dataPath
                                  , 'Poisson Blocks Shaping C2'             ... experName
                                  , 'Cohort4'                           ... cohortName
                                  , numDataSync                             ... numDataSync
                                  , varargin{:}                             ...
                                  );
    
end
