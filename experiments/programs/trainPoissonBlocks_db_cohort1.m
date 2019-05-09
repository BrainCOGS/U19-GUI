function regiment = trainPoissonBlocks_db_cohort1(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\dbakshinskaya\PoissonTowers_1' ... dataPath
                                  , 'PoissonBlocksReboot'                     ... experName
                                  , 'cohort1'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
