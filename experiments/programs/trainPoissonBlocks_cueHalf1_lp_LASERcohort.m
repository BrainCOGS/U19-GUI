function regiment = trainPoissonBlocks_cueHalf1_lp_LASERcohort(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\lucas\blocksReboot' ... dataPath
                                  , 'PoissonBlocksReboot'                     ... experName
                                  , 'LASERcohort_cueHalf1'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
