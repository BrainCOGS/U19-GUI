function regiment = edwardnieh_train4(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\edward\PoissonTowers_4' ... dataPath
                                  , 'PoissonBlocksReboot4'                     ... experName
                                  , 'cohort4'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
