function regiment = trainPoissonBlocks_mem_lp_LASERcohort(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\lucas\blocksReboot' ... dataPath
                                  , 'PoissonBlocksReboot'                     ... experName
                                  , 'LASERcohort_mem'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
