function [s] = cell2string(c)
%CELL2STRING 
% Make a cell string array to multiline representation

s = '';
for i=1:length(c)
    s = [s, c{i}, newline];
end

end

