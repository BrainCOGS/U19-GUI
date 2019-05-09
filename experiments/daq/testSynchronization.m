%%
% Cleanup
nidaqTest('end');
if false
  compile_utilities('nidaqTest', '-O');
end

% Configuration
device              = 1;
port                = 0;

% CLK lines (hardware wired)
sCLKline            = 10;
rCLKline            = 15;
tCLKline            = 3;      % PFI

% DTA lines (hardware wired)
sDTAline            = 8;
rDTAline            = 13;

% TRG lines (hardware wired)
sTRGline            = 23;
rTRGline            = 24;

%%
% Test parameters
nRepeats            = 100;
% bufSize             = 2048;
bufSize             = 4096;

% Pre-generate test dataset
% dataLength          = [1:10 12:2:20];
dataLength          = [1 8 20 40 60 80 96 130 170 200 250 300];
iOneDouble          = find(dataLength == 64/8);
i12Doubles          = find(dataLength == 12*64/8);
fprintf('Generating datasets of length %d-%d...\n', dataLength(1), dataLength(end));
data                = cell(size(dataLength));
for iData = 1:numel(data)
  data{iData}       = randi([0 255], 1, dataLength(iData), 'uint8');
end


%% Basic operations
nidaqTest('init', device, port, sCLKline, rCLKline, tCLKline, sDTAline, rDTAline, sTRGline, rTRGline);

% tic; nidaqTest('send', uint8('hello world!'), true); toc, [packet, dtime] = nidaqTest('receive', 1)

%% Benchmarking

numBytes            = dataLength(1):dataLength(end);
numBits             = 5 + 3 * (numBytes * 8);
lagTheoryRaw        = numBits * 1000 / 1e6;
lagTheoryBuf        = ceil(numBits/bufSize) * bufSize * 1000 / 1e6;

durSend             = nan(nRepeats, numel(data));
lagReceive          = nan(nRepeats, numel(data));
for iData = 1:numel(data)
  for iRep = 1:nRepeats
    tSend           = tic;
    nidaqTest('send', data{iData}, false);
    durSend(iRep, iData)              = toc(tSend);
%     [packet, lagReceive(iRep,iData)]  = nidaqTest('receive', 1);
    pause(0.05);
  end
end
durSend             = mean(durSend   ,1) / 1000;
lagReceive          = mean(lagReceive,1);

fig                 = figure('Units', 'pixels', 'Position', [100 100 500 400]);
axs                 = axes( 'Parent'      , fig             ...
                          , 'XGrid'       , 'on'            ...
                          , 'YGrid'       , 'on'            ...
                          );
line(dataLength, durSend, 'Parent', axs, 'Color', [0 0 0]);
xlabel('Data length (# bytes)');
ylabel('send() duration (ms/call)');

fig                 = figure('Units', 'pixels', 'Position', [600 100 500 400]);
axs                 = axes( 'Parent'      , fig             ...
                          , 'XGrid'       , 'on'            ...
                          , 'YGrid'       , 'on'            ...
                          );
line(numBytes  , lagTheoryRaw , 'Parent', axs, 'Color', [1 0 0]);
line(numBytes  , lagTheoryBuf , 'Parent', axs, 'Color', [0 0 1]);
line(dataLength, lagReceive   , 'Parent', axs, 'Color', [0 0 0]);
line( dataLength(iOneDouble), lagReceive(iOneDouble), 'Parent', axs   ...
    , 'MarkerFaceColor', [0 0.8 0], 'MarkerEdgeColor', 'none'         ...
    , 'Marker', 'd', 'MarkerSize', 6, 'Color', 'none'                 ...
    );
line( dataLength(i12Doubles), lagReceive(i12Doubles), 'Parent', axs   ...
    , 'MarkerFaceColor', [0 0.8 0], 'MarkerEdgeColor', 'none'         ...
    , 'Marker', 's', 'MarkerSize', 6, 'Color', 'none'                 ...
    );

xlabel('Data length (# bytes)');
ylabel('receive() lag (ms)');
legend( axs                                                 ...
      , { 'Theory (1MHz)'                                   ...
        , sprintf('Theory (%d-bit buffer)', bufSize)        ...
        , 'Measured'                                        ...
        , '(data = 1 double)'                               ...
        , '(data = 12 doubles)'                             ...
        }                                                   ...
      , 'Location'  , 'NorthWest'                           ...
      );

