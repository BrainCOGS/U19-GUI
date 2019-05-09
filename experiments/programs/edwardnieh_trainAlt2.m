function regiment = edwardnieh_trainAlt2(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\edward\PoissonTowers_Alt2' ... dataPath
                                  , 'PoissonBlocksRebootAlt2'                     ... experName
                                  , 'cohortAlt2'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
