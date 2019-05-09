function regiment = trainPoissonBlocksA_lp_pilotCohort(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\lucas\blocksPilot' ... dataPath
                                  , 'Poisson Blocks A'                     ... experName
                                  , 'pilotCohort'                         ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
