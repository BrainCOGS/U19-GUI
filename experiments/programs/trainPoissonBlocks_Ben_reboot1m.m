function regiment = trainPoissonBlocks_Ben_reboot1m(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\Ben\blocksreboot1' ... dataPath
                                  , 'PoissonBlocksCondensed3m_Ben'                     ... experName
                                  , 'reboot1'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
