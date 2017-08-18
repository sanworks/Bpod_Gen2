%
% [int r]       = IsRunning(sm)  return 1 if running, 0 if halted    
%
function [isrunning] = IsRunning(sm)

isrunning = str2num(DoQueryCmd(sm, 'IS RUNNING'));
return;
end
