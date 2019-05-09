function regiment = edwardnieh_train(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\edward\PoissonTowers_1' ... dataPath
                                  , 'PoissonBlocksReboot'                     ... experName
                                  , 'cohort1'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
