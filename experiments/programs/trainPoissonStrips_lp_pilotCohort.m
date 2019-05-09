function regiment = trainPoissonStrips_lp_pilotCohort(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\lucas\stripsPilot' ... dataPath
                                  , 'Poisson Strips'                     ... experName
                                  , 'pilotCohort'                         ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
