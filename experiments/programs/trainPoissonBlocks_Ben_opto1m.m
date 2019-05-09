function regiment = trainPoissonBlocks_Ben_opto1m(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\Ben\opto1' ... dataPath
                                  , 'PoissonBlocksCondensed3m_Ben'                     ... experName
                                  , 'opto1'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
