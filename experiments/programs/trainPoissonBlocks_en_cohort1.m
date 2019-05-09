function regiment = trainPoissonBlocks_en_cohort1(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\enieh\PoissonTowers_1' ... dataPath
                                  , 'PoissonBlocksReboot'                     ... experName
                                  , 'cohort1'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
