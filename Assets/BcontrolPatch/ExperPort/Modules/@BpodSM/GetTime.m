% [double time] = GetTime(sm)    
%                Gets the time, in seconds, that has elapsed since
%                the last call to Initialize().
function [time] = GetTime(sm)
  time = str2double(DoQueryCmd(sm, 'GET TIME'));
  return;
