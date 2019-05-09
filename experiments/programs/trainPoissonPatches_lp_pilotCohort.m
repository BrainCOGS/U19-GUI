function regiment = trainPoissonPatches_lp_pilotCohort(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\lucas\patchesPilot' ... dataPath
                                  , 'Poisson Patches'                     ... experName
                                  , 'pilotCohort'                         ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
