function [portins, portouts] = cleanPortTimes(portins, portouts)
% Cleanse port data
% [portins, portouts] = cleanPortTimes(portins, portouts)
%
% 

if ~isempty(portins)
    if isempty(portouts)
        portouts = NaN;
    end
    
    % Handle edge cases
    if portins(1) > portouts(1) % an out before an in
        portins = [NaN portins];
    end
    if portins(end) > portouts(end) % in before trial end
        portouts(end + 1) = NaN;
    end
elseif ~isempty(portouts)
    portins = NaN;
else
    portins = [];
    portouts = [];
end