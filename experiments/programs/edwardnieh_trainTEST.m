function regiment = edwardnieh_trainTEST(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\edward\PoissonTowers_TEST' ... dataPath
                                  , 'PoissonBlocksRebootTEST'                     ... experName
                                  , 'cohortTEST'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
