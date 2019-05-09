function regiment = trainPoissonBlocks_lp_WideFieldCohort2(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\lucas\blocksReboot' ... dataPath
                                  , 'PoissonBlocksCondensed3m'                     ... experName
                                  , 'WideFieldCohort2'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
