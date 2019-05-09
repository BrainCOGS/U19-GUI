%% Some standard ways in which user keypress can be used to control a ViRMen experiment.
function vr = processKeypress(vr, console)

  persistent vrMovieWriter;
  if vr.iterations < 2
    vrMovieWriter = [];
  end

%   if ~isempty(vr.keyPressed) && isfinite(vr.keyPressed)
%     vr.keyPressed
%   end

  switch vr.keyPressed
    
    % Increment maze ID to a more difficult configuration
    case 334    % Numpad +
      if vr.mazeID + vr.mazeChange < numel(vr.mazes)
        vr.mazeChange = vr.mazeChange + 1;
        console.log('Next maze will be %d %s = %d', vr.mazeID, incr2str(vr.mazeChange), vr.mazeID + vr.mazeChange);
      end
      
    % Decrement maze ID to an easier configuration
    case 333    % Numpad -
      if vr.mazeID + vr.mazeChange > 1
        vr.mazeChange = vr.mazeChange - 1;
        console.log('Next maze will be %d %s = %d', vr.mazeID, incr2str(vr.mazeChange), vr.mazeID + vr.mazeChange);
      end
      
    % Give reward
    case 82     % R
      deliverReward(vr, vr.rewardMSec);
      console.log('Delivered 4ul reward (%.3gms valve opening time)', vr.rewardMSec);
      
    % Toggle trial selection method (pseudo-random R/L draws vs. R/L only trials)
    case 331    % Numpad /
      if isfield(vr, 'protocol')
        vr.protocol.nextDrawMethod();
      end

%     % Toggle comment entry status for ExperimentLog
%     case 330    % Numpad .
%       if isfield(vr, 'logger')
%         vr.logger.toggleComment();
%       end

    % Forfeit a trial, as if the animal has made a wrong choice
    case 261    % Delete
      vr.choice     = Choice.nil;
      vr.state      = BehavioralState.ChoiceMade;
      if isfield(vr, 'protocol')
        trial       = sprintf(' %d', vr.protocol.currentTrial);
      else
        trial       = '';
      end
      
      console.log('Forfeiting trial%s with choice = %s', trial, char(vr.choice));
      
    % Increase reward factor
    case 266    % Page up
      newScale = min(vr.protocol.rewardScale + 0.2, 3);
      vr.protocol.setRewardScale( newScale );
      if newScale >= 1.8; vr.numRewardDrops = 2; end
      console.log ( 'User override: Scaling rewards by %.3g (%.3g uL)'                  ...
                  , vr.protocol.rewardScale                                             ...
                  , vr.protocol.rewardScale * 1000*RigParameters.rewardSize             ...
                  );
      
    % Decrease reward factor
    case 267    % Page down
      newScale = max(vr.protocol.rewardScale - 0.2, 1);
      vr.protocol.setRewardScale( newScale );
      if newScale < 1.8; vr.numRewardDrops = 1; end
      console.log ( 'User override: Scaling rewards by %.3g (%.3g uL)'                  ...
                  , vr.protocol.rewardScale                                             ...
                  , vr.protocol.rewardScale * 1000*RigParameters.rewardSize             ...
                  );

    % Start/stop movie recording
    case 332    % Numpad *
      if isempty(vrMovieWriter)
        [path,name]   = parsePath(vr.logger.logFile);
        if ~exist(path, 'dir')
          mkdir(path);
        end
        vrMovieFile   = fullfile(path, [name datestr(now, '_yyyymmdd_HHMMSS')]);
        vrMovieWriter = VideoWriter(vrMovieFile, 'MPEG-4');
        vrMovieWriter.FrameRate = 120;   % Human tuned
        open(vrMovieWriter);
        
        console.log('Begin capture of movie in %s%s%s', vrMovieWriter.Path, filesep, vrMovieWriter.Filename);
      else
        close(vrMovieWriter);
        vrMovieFile   = fullfile(vrMovieWriter.Path, vrMovieWriter.Filename);
        console.log('Movie stored in %s%s%s', vrMovieFile);
%         explorer(vrMovieFile);
        vrMovieWriter = [];
      end
      
%     % Toggle display of orientation cues
%     case 259    % Backspace
%       vr.orientationTargets = ~vr.orientationTargets;
%       vr                    = cacheMazeConfig(vr, vr.orientationTargets);
% 
%       if vr.orientationTargets
%         console.log('Distal visual cues will be turned on for orientation');
%       else
%         console.log('Distal visual cues will be turned off');
%       end
      
    % Debug break
    case 284    % Pause
      keyboard;
      
  end


  if ~isempty(vrMovieWriter)
    frame   = virmenGetFrame(1);
    writeVideo(vrMovieWriter, flipud(frame));
  end

end
