% [int n_vars] = GetVarLogCounter(sm)   
%                Get the number of variables that have been logged
%                since the last call to Initialize().
function [nvars] = GetVarLogCounter(sm)

  nvars = str2num(DoQueryCmd(sm, 'GET VARLOG COUNTER'));
  return;
  

