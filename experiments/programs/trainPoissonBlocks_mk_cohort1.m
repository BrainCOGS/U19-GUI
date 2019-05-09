function regiment = trainPoissonBlocks_mk_cohort1(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\mkislin\Towers1' ... dataPath
                                  , 'PoissonBlocksReboot'                     ... experName
                                  , 'cohort1'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
