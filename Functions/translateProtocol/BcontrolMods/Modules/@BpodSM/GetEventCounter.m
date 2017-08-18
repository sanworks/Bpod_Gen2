% [int nevents] = GetEventCounter(sm)   
%                Get the number of events that have occurred since
%                the last call to Initialize().
function [nevents] = GetEventCounter(sm)

  nevents = str2num(DoQueryCmd(sm, 'GET EVENT COUNTER'));
  return;
  

