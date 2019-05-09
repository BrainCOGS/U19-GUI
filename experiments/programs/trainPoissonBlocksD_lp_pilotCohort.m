function regiment = trainPoissonBlocksD_lp_pilotCohort(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\lucas\blocksPilotD' ... dataPath
                                  , 'Poisson Blocks D'                     ... experName
                                  , 'pilotCohort'                         ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
