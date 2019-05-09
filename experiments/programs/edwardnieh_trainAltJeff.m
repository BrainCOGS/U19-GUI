function regiment = edwardnieh_trainAltJeff(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\edward\PoissonTowers_AltJeff' ... dataPath
                                  , 'PoissonBlocksRebootAltJeff'                     ... experName
                                  , 'cohortAltJeff'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
