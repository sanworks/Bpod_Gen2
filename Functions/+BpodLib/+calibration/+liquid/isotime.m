function datestring = isotime()
% Get the current time in ISO format
% :return datestring: the current time in ISO format
% :rtype datestring: char
dt = datetime('now');
datestring = char(dt, 'yyyy-MM-dd HH:mm:ss');
datestring = datestr(now, 31);
end