function regiment = trainPoissonPatchesA2_ib_cohort1(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\ibusack\PoissonPatchesA_2'   ... dataPath
                                  , 'Poisson Patches'                     ... experName
                                  , 'cohort1'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
