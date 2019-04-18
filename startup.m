virmenDir = fileparts(mfilename('fullpath'));
% guiDir    = fullfile(virmenDir, 'bin', 'gui');
subDirs   = strsplit(genpath(virmenDir), pathsep);
vetoDir   = { fullfile(virmenDir, '.git')                     ...
            , fullfile(virmenDir, 'bin', 'gui', 'builtin')    ...
            , fullfile(virmenDir, 'bin', 'gui', 'icons')      ...
            , fullfile(virmenDir, 'bin', 'engine', 'GL')      ...
            , fullfile(virmenDir, 'sensors', 'ADNS')          ...
            , fullfile(virmenDir, 'database', 'images')       ...
            };
if ~isempty(which('layoutRoot'))
  vetoDir{end+1}  = fullfile(virmenDir, 'GUILayout');
end

subDirs( cellfun(@isempty,subDirs) )  = [];
for iVeto = 1:numel(vetoDir)
  subDirs( strncmp(subDirs, vetoDir{iVeto}, numel(vetoDir{iVeto})) )  = [];
end

addpath(strjoin(subDirs, pathsep));
clear('virmenDir', 'subDirs', 'vetoDir', 'iVeto');
