function regiment = edwardnieh_trainAlt(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\edward\PoissonTowers_Alt' ... dataPath
                                  , 'PoissonBlocksRebootAlt'                     ... experName
                                  , 'cohortAlt'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
