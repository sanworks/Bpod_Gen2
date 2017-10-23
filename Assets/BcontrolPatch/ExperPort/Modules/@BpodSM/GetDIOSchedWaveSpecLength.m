% n = GetDIOSchedWaveSpecLength(sm)   Get the number of items in current SchedWave specification mode
% 
% This command asks the FSMServer for the number of items it is currently
% set to handle in a  scheduled wave specification. Current possible items are:
%
% ID IN_EVENT_COL OUT_EVENT_COL DIO_LINE SOUND_TRIG PREAMBLE SUSTAIN REFRACTION [LOOP=0] [SW_TRIGGER] [SW_UNTRIGGER]
%
% The allowed number of returns from this function are 8 (the default), in which case no 'loop'
% parameter is assumed to exist, or 9, in which case the 'loop' parameter
% is to be passed in, or 11, in which case the IDs of shced waves to
% trigger and to untrigger are also passed in.
%

function [res] = GetDIOSchedWaveSpecLength(sm)

if ~min_server(sm, 220090628, mfilename),
    res = '';
    return;
end;

[res] = str2double(DoQueryCmd(sm, 'GET DIO SCHED WAVE NUM COLUMNS\n'));
  
return;
