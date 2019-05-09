function [mazes, criteria, globalSettings, vr] = PoissonBlocksWithLandmarks(vr)

  %________________________________________ 1 _____ 2 _____ 3 _____ 4 _____ 5 _____ 6 _____ 7 _____ 8 _____ 9 _________ 10 ____ 11 ____ 12 _____
  mazes     = struct( 'lStart'          , {5     , 30    , 30    , 30    , 30    , 30    , 30    , 30    , 30         , 30    , 30    , 30   }   ...
                    , 'lCue'            , {45    , 120   , 280   , 280   , 280   , 280   , 280   , 200   , 200        , 200   , 200   , 200  }   ...
                    , 'lMemory'         , {10    , 20    , 20    , 20    , 20    , 20    , 20    , 100   , 100        , 100   , 100   , 100  }   ...
                    , 'tri_turnHint'    , {true  , true  , true  , true  , true  , true  , false , false , false      , false , false , true }   ... true/false = presence of visual guides; inf = turn off guide in delay region; other numbers (cm) = turn off guides this far from the END of the maze (effective delay); -inf = bilateral guides
                    , 'hHint'           , {30    , 30    , 30    , 22    , 15    , 6     , 6     , 6     , 6          , 6     , 6     , 30   }   ... height of visual guides (cm)
                    , 'landmarkSkip'    , {5     , 3     , 0     , 0     , 0     , 0     , 0     , 0     , 0          , 0     , 0     , 0    }   ... reduces number of landmarks shown by this skip factor
                    , 'cueDuration'     , {nan   , inf   , inf   , inf   , inf   , inf   , inf   , inf   , inf        , inf   , inf   , inf  }   ... seconds; inf = turn off in delay region; nan = always invisible
                    , 'cueVisibleAt'    , {10    , 10    , 10    , 10    , 10    , 10    , 10    , 10    , 10         , 10    , 10    , 10   }   ... cm in front of mouse
                    , 'cueProbability'  , {inf   , inf   , inf   , inf   , inf   , inf   , inf   , inf   , 2.5        , 1.6   , 1.2   , 1.2  }   ...
                    , 'cueDensityPerM'  , {3     , 3.8   , 4.2   , 4.2   , 4.2   , 4.2   , 4.2   , 4.2   , 4.5        , 4.8   , 5     , 5    }   ...
                    , 'antiFraction'    , {0     , 0     , 0     , 0     , 0     , 0     , 0     , 0     , 0          , 0     , 0     , 0.2  }   ... fraction of trials with inverted reward condition
                    );
  criteria  = struct( 'numTrials'       , {10    , 40    , 80    , 80    , 80    , 80    , 80    , 80    , 80         , 80    , 80    , 80   }   ...
                    , 'numTrialsPerMin' , {2     , 2     , 2     , 2     , 2     , 2     , 2     , 2     , 2          , 2     , 2     , 2    }   ...
                    , 'criteriaNTrials' , {inf   , inf   , 80    , 100   , 100   , 100   , 100   , 100   , 100        , 100   , 100   , 100  }   ...
                    , 'warmupNTrials'   , {[]    , []    , []    , []    , 30    , 30    , 30    , 30    , [10, 15]   , 10    , 10    , 20   }   ...
                    , 'numSessions'     , {0     , 0     , 1     , 1     , 1     , 1     , 1     , 1     , 1          , 1     , 1     , 1    }   ...
                    , 'performance'     , {0     , 0     , 0.9   , 0.85  , 0.85  , 0.8   , 0.8   , 0.8   , 0.75       , 0.7   , 0.65  , 0.65 }   ...
                    , 'maxBias'         , {inf   , 0.2   , 0.1   , 0.1   , 0.15  , 0.15  , 0.15  , 0.15  , 0.20       , 0.20  , 0.20  , 0.20 }   ...
                    , 'warmupMaze'      , {[]    , []    , []    , []    , 4     , 5     , 5     , 5     , [5   ,7]   , 5     , 5     , 5    }   ...
                    , 'warmupPerform'   , {[]    , []    , []    , []    , 0.8   , 0.8   , 0.8   , 0.8   , [0.85,0.8] , 0.85  , 0.85  , 0.85 }   ...
                    , 'warmupBias'      , {[]    , []    , []    , []    , 0.1   , 0.1   , 0.1   , 0.1   , [0.1 ,0.1] , 0.1   , 0.1   , 0.1  }   ...
                    , 'warmupMotor'     , {[]    , []    , []    , []    , 0     , 0     , 0     , 0     , [0.75,0.75], 0.75  , 0.75  , 0.75 }   ...
                    , 'easyBlock'       , {nan   , nan   , nan   , nan   , 5     , 5     , 5     , 5     , 5          , 7     , 7     , nan  }   ... maze ID of easy block    
                    , 'easyBlockNTrials', {10    , 10    , 10    , 10    , 10    , 10    , 10    , 10    , 10         , 10    , 10    , 10   }   ... number of trials in easy block   
                    , 'numBlockTrials'  , {20    , 20    , 20    , 20    , 40    , 40    , 40    , 40    , 40         , 40    , 40    , 40   }   ... number of trials for sliding window performance
                    , 'blockPerform'    , {.7    , .7    , .7    , .7    , .7    , .7    , .7    , .7    , .7         , .6    , .55   , .55  }   ... performance threshold to go into easy block
                    );

  globalSettings          = {'cueMinSeparation', 12, 'fracDuplicated', 0.5, 'trialDuplication', 4, 'landmarkVisibleAt', 40, 'skySwitchInterval', [0.3,1]};
  vr.numMazesInProtocol   = 11;
  vr.stimulusGenerator    = @PoissonStimulusTrain;
  vr.stimulusParameters   = {'cueVisibleAt', 'cueDensityPerM', 'cueProbability', 'nCueSlots', 'cueMinSeparation'};
  vr.inheritedVariables   = {'cueDuration', 'cueVisibleAt', 'lCue', 'lMemory', 'antiFraction'};

  
  if nargout < 1
    figure; plot([mazes.lStart] + [mazes.lCue] + [mazes.lMemory], 'linewidth',1.5); xlabel('Shaping step'); ylabel('Maze length (cm)'); grid on;
    hold on; plot([mazes.lMemory], 'linewidth',1.5); legend({'total', 'memory'}, 'Location', 'east'); grid on;
    figure; plot([mazes.lMemory] ./ [mazes.lCue], 'linewidth',1.5); xlabel('Shaping step'); ylabel('L(memory) / L(cue)'); grid on;
    figure; plot([mazes.cueDensityPerM], 'linewidth',1.5); set(gca,'ylim',[0 6.5]); xlabel('Shaping step'); ylabel('Tower density (count/m)'); grid on;
    hold on; plot([mazes.cueDensityPerM] .* (1 - 1./(1 + exp([mazes.cueProbability]))), 'linewidth',1.5);
    hold on; plot([mazes.cueDensityPerM] .* (1./(1 + exp([mazes.cueProbability]))), 'linewidth',1.5);
    hold on; plot([1 numel(mazes)], [1 1].*(100/globalSettings{2}), 'linewidth',1.5, 'linestyle','--');
    legend({'\rho_{L} + \rho_{R}', '\rho_{salient}', '\rho_{distract}', '(maximum)'}, 'location', 'southwest');
    
    [muSalient, muDistract] = poissonCueDensity([mazes.cueDensityPerM], [mazes.cueProbability]);
    disp(significantDigits([muSalient; muDistract] * mazes(end-1).lCue/100, 2));
  end

end
