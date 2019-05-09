function regiment = edwardnieh_train2(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\edward\PoissonTowers_2' ... dataPath
                                  , 'PoissonBlocksReboot2'                     ... experName
                                  , 'cohort2'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
