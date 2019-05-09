function regiment = edwardnieh_trainNpHR(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\edward\PoissonTowers_NpHR' ... dataPath
                                  , 'PoissonBlocksRebootNpHR'                     ... experName
                                  , 'cohortNpHR'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
