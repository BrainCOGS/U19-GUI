function [lowWeightFlag,extraVolume,veryLowWeightFlag] = hasLowWeight(logs,mice,referenceWeights)

% [lowWeightFlag,extraVolume] = hasLowWeight(logs,mice,reference weights)
% flags if mouse has lower than 80% of initial weight and calculates required extra volume
% logs are single-day animal structures and mice, mouse info sheets
% supports structure arrays
% reference weights is an optional vector of reference weights to be used
% in addition to initial weigghts, same 80% threshold

if nargin < 3 || isempty(referenceWeights); referenceWeights = zeros(1,numel(logs)); end

initialWeights  = [mice(:).initWeight];
weightThreshold = initialWeights.*.8;
todaysWeight    = [logs(:).weight];       
lowWeightFlag   = todaysWeight < weightThreshold | todaysWeight < referenceWeights-1;
extraVolume     = max([referenceWeights; weightThreshold]) - todaysWeight;
extraVolume(extraVolume > 2) = 2;
veryLowWeightFlag            = todaysWeight < initialWeights.*.7;