% prog = GetStateProgram(sm)
%                Query the FSM server to retreive the exact
%                text of the C program it is using.
%
function [lines] = GetStateProgram(sm)

  lines = DoLinesCmd(sm, 'GET STATE PROGRAM');
%  prog = '';
%  for i=1:size(lines,1),
%    prog = [ prog lines(i,:) ];
%  end;
  return;
  
