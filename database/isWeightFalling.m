function weightLossFlag = isWeightFalling(logs)

% weightLossFlag = isWeightFalling(logs)
% takes cell array of logs and returns a logical flag for each animal if
% weight loss is greater than 1g in a day or steady > .2g weight loss over
% the previous 5 days

if ~iscell(logs); logs = {logs}; end
weightLossFlag    = cellfun(@(x)(steadyWeightLoss(x)),logs);

end

function losingWeight = steadyWeightLoss(log)

dayIdx  = max([1 numel(log)-5]):numel(log);
weights = [log(dayIdx).weight];

if numel(weights) < 2 || isempty(weights)
  losingWeight = false;
elseif numel(weights) == 2
  losingWeight = weights(end) < weights(end-1) - 1;
else
  dw           = diff(weights);
  losingWeight = weights(end) < mean(weights(end-2:end-1)) - 1 | ...
                 (mean(dw) <= .2 & sum(dw<0) == numel(dw)); 
end

end