function regiment = trainPoissonBlocks_lp_LASERcohort(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\lucas\blocksReboot' ... dataPath
                                  , 'PoissonBlocksRebootB'                     ... experName
                                  , 'LASERcohort'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
