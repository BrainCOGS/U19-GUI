function regiment = edwardnieh_train3(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\edward\PoissonTowers_3' ... dataPath
                                  , 'PoissonBlocksReboot3'                     ... experName
                                  , 'cohort3'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
