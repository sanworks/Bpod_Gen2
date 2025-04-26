function datestring = isotime()
% Get the current time in ISO format
% :return datestring: the current time in ISO format
% :rtype datestring: char
datestring = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
end