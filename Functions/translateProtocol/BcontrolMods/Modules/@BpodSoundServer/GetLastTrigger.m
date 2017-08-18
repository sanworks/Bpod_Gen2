% [trig_num] = GetLastTrigger(sm) 
%
%  Returns the trigger id of the last sound event that played.  Negative
%  indicates STOP events, positive is a sound PLAY event.  The event id
%  is the same id that was used to identify the sound when it was loaded
%  with LoadSound.  If 0 is returned, no sound events have occurred since
%  the last reset.
%
function [ret] = GetLastTrigger(sm)

     ret = DoQueryCmd(sm, sprintf('GET LAST EVENT'));
