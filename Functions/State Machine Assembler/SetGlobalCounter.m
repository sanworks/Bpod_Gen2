%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
function sma = SetGlobalCounter(sma, CounterNumber, TargetEvent, Threshold)
% Example usage:
% sma = SetGlobalCounter(sma, 1, 'Port1in', 5); % sets counter 1 to trigger
% a threshold crossing event after 5 pokes in port 1, irrespective of state.

global BpodSystem
if ischar(Threshold)
    error('Global counter thresholds must be numbers')
end
if Threshold < 0
    error('Global counter thresholds must be positive.')
end
if rem(Threshold,1) > 0
    error('Global counter thresholds must be whole numbers.')
end
nCounters = length(sma.GlobalCounterThresholds);
if CounterNumber > nCounters
    error(['Only ' num2str(nCounters) ' global counters are available in the current Bpod version.']);
end
TargetEventCode = find(strcmp(TargetEvent, BpodSystem.StateMachineInfo.EventNames));
if isempty(TargetEventCode)
    error(['Error setting global counter. Target event ''' TargetEvent ''' is invalid syntax.'])
end

sma.GlobalCounterThresholds(CounterNumber) = Threshold;
sma.GlobalCounterEvents(CounterNumber) = TargetEventCode;
sma.GlobalCounterSet(CounterNumber) = 1;