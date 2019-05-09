%% Gets the next maze ID to be run by the animal, given its past history of sessions run and performance levels.
function [vr, mazeChanged] = decideMazeAdvancement(vr, numMazes)
  
  %% Default to the total number of available mazes
  if nargin < 2
    numMazes                = numel(vr.mazes);
  end
  

  %% Special case for user override
  criteria                  = vr.mazes(vr.mainMazeID).criteria;
  if vr.mazeChange ~= 0
    mazeChanged             = true;
    vr.mazeID               = vr.mazeID + vr.mazeChange;
    vr.updateReward         = 1;
    vr.mazeChange           = 0;
    vr.easyBlockFlag        = 0; % in case it's done during easy block
    
    % If the new maze is part of the warmup sequence, adjust the stored
    % index to match, otherwise treat it as setting the main maze
    vr.warmupIndex          = find(criteria.warmupMaze == vr.mazeID, 1, 'first');
    if isempty(vr.warmupIndex)
      vr.warmupIndex        = 0;
      vr.mainMazeID         = vr.mazeID;
    end

    vr.protocol.log('User enforced maze %d (main maze %d, warmup maze #%d)', vr.mazeID, vr.mainMazeID, vr.warmupIndex);
    return;
  end
  
  %% check for automatic session termination / demotion to visually-guided maze
  [vr,mazeChanged] = autoTerminateSession(vr);
  if mazeChanged || vr.extraWaterMaze || vr.experimentEnded; return; end

  %% Obtain performance criteria from online tally
  mazeChanged               = false;
  [performance, bias, goodFraction, numTrials, numPerMin]                 ...
                            = vr.protocol.getStatistics();
  
  %% Special case for first trial
  if vr.iterations < 2
    mazeChanged             = true;
                          
  % If running a main maze, check for advancement or demotion
  elseif vr.warmupIndex < 1
    % Within-session advancement
    if      criteria.numSessions < 1                                      ...
        &&  ~isempty(numTrials)                                           ...
        &&  all(numTrials   >= criteria.numTrials/2)                      ...
        &&  numPerMin       >= criteria.numTrialsPerMin                   ...
        &&  performance     >= criteria.performance                       ...
        &&  bias            <  criteria.maxBias                           ...
        &&  vr.mainMazeID   <  numMazes                                   
     
      mazeChanged           = true;
      vr.mainMazeID         = vr.mainMazeID + 1;
      criteria              = vr.mazes(vr.mainMazeID).criteria;
      if isempty(criteria.warmupMaze)
        vr.warmupIndex      = 0;
        vr.mazeID           = vr.mainMazeID;
      else
        vr.warmupIndex      = 1;
        vr.mazeID           = criteria.warmupMaze(vr.warmupIndex);
      end
      vr.protocol.log('Advanced to maze %d (main maze %d, warmup maze #%d)', vr.mazeID, vr.mainMazeID, vr.warmupIndex);
    
    % otherwise decide whether to go to an easy block if applicable
    elseif   criteria.numSessions >= 1                                   ...
            &&  isfield(criteria,'easyBlock')
        
        if ~isnan(criteria.easyBlock)       
            if vr.easyBlockFlag
                % if in easy block, no perfromance is enforced, only trial #
                if sum(numTrials) == criteria.easyBlockNTrials
                    mazeChanged      = true;
                    vr.mazeID        = vr.mainMazeID;
                    vr.easyBlockFlag = 0;
                    vr.updateReward  = 0;
                    vr.protocol.log('Back to main maze (maze %d)', vr.mainMazeID);
                end
                
            else
                % if in main maze, go to easy block if performance over numBlockTrials
                % falls below the blockPerform threshold
                if  vr.mazeID == vr.mainMazeID                                    ...
                        &&  sum(numTrials)   >= criteria.numBlockTrials           ...
                        &&  performance <  criteria.blockPerform
                    mazeChanged      = true;
                    vr.mazeID        = criteria.easyBlock;
                    vr.easyBlockFlag = 1;
                    vr.updateReward  = 0;
                    vr.protocol.log('Switched to easy block due to poor performance (maze %d)', vr.mazeID);
                end
            end
        end
        %{
    *** NOT USEFUL ***
      
    % Demotion to easier maze
    elseif  ~isempty(criteria.demoteBlockSize)                            ...
        &&  all(numTrials(:) > criteria.demoteBlockSize/2)                ...
        &&  issorted(performance)                                         ...
        &&( performance(1)  <  criteria.demotePerform                     ...
        ||  bias(1)         >= criteria.demoteBias                        ...
          )
      mazeChanged           = true;
      vr.mazeID             = vr.mazeID - 1;
      vr.warmupIndex        = 0;
      vr.protocol.log('Demoted to maze %d (main maze %d, warmup maze #%d)', vr.mazeID, vr.mainMazeID, vr.warmupIndex);
    %}
    end
    
  % If running a warmup maze, check for advancement to a second warmup or
  % to the main maze
  elseif    ~isempty(numTrials)                                           ...
        &&  all(numTrials   >= criteria.warmupNTrials(vr.warmupIndex)/2)  ...
        &&  performance     >= criteria.warmupPerform(vr.warmupIndex)     ...
        &&  bias            <  criteria.warmupBias(vr.warmupIndex)        ...
        &&  goodFraction    >= criteria.warmupMotor(vr.warmupIndex)
      mazeChanged           = true;
      vr.warmupIndex        = vr.warmupIndex + 1;
  
    if vr.warmupIndex > numel(criteria.warmupMaze)
      vr.mazeID             = vr.mainMazeID;
      vr.warmupIndex        = 0;
      vr.protocol.log('Done with warmup, running main maze %d', vr.mazeID);
    else
      vr.mazeID             = criteria.warmupMaze(vr.warmupIndex);
      vr.protocol.log('Running warmup maze %d (main maze %d, warmup maze #%d)', vr.mazeID, vr.mainMazeID, vr.warmupIndex);
    end
  end

end
