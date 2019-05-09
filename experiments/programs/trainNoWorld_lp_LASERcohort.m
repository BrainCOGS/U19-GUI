function regiment = trainNoWorld_lp_LASERcohort(numDataSync, varargin)

 if nargin < 1
    numDataSync = [];
  end

  regiment  = runCohortExperiment ( 'C:\Data\lucas\blocksReboot' ... dataPath
                                  , 'noWorld'                     ... experName
                                  , 'LASERcohort'                             ... cohortName
                                  , numDataSync                           ... numDataSync
                                  , varargin{:}                           ...
                                  );
    
end
