% sm = StopSound(sm) 
%                Forces the soundmachine to stop any sounds it may 
%                (or may not) be currently playing.  Stop ramping
%                is applied to sounds that are prematurely stopped
%                (see LoadSound() for a description of stop ramping).
function [sm] = StopSound(sm)

     id = GetLastTrigger(sm);
     if (isa(id, 'char')),  id = str2num(id); end;
     if (id > 0), DoSimpleCmd(sm, sprintf('TRIGGER %d\n', -id)); end;
     sm = sm;
     
