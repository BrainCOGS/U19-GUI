%% Loads a sound file and computes its duration
function sound = loadSound(wavFile, durationFactor, amplitudeFactor, repetitions)

  if nargin < 2
    durationFactor    = 1;
  end
  if nargin < 3
    amplitudeFactor   = 1;
  end
  if nargin < 4
    repetitions       = 1;
  end

  [sound.y, sound.Fs] = audioread(wavFile);
  sound.y             = repmat(sound.y, repetitions, 1);
  sound.y             = amplitudeFactor .* sound.y;
  sound.duration      = durationFactor * numel(sound.y) / sound.Fs;
  sound.player        = audioplayer(sound.y, sound.Fs);

end
