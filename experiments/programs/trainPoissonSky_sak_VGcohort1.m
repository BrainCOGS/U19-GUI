function regiment = trainPoissonSky_sak_VGcohort1(numDataSync, varargin)

  if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\sakoay\PoissonSkyVGAT_1'         ... dataPath
                                  , 'Poisson Sky'                             ... experName
                                  , 'VGATcohort1'                             ... cohortName
                                  , numDataSync                               ... numDataSync
                                  , varargin{:}                               ...
                                  );
    
end
