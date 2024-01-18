%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

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

% SetGlobalCounter() adds a global counter to an existing state machine description. 
% Global counters count instances of a target event, and compare the total to a threshold. 
% When the threshold is exceeded, an event is generated.
%
% Arguments:
% sma = a state machine description that will be modified with the new global counter
% counterIndex = The index of the global counter to add
% targetEvent = The name of the event to monitor
% threshold = The number of instances of the event to count before
% generating a global counter event
%
% Returns: sma, the state machine description
%
% Example usage:
% sma = SetGlobalCounter(sma, 1, 'Port1in', 5); % sets counter 1 to trigger
% a threshold crossing event after 5 pokes in port 1, irrespective of state.

function sma = SetGlobalCounter(sma, counterIndex, targetEvent, threshold)

global BpodSystem % Import the global BpodSystem object

% Validate threshold
if ischar(threshold)
    error('Global counter thresholds must be numbers')
end
if threshold < 0
    error('Global counter thresholds must be positive.')
end
if rem(threshold,1) > 0
    error('Global counter thresholds must be whole numbers.')
end

% Validate counter index
nCounters = length(sma.GlobalCounterThresholds);
if counterIndex > nCounters
    error(['Only ' num2str(nCounters) ' global counters are available in the current Bpod version.']);
end

% Validate target event
targetEventCode = find(strcmp(targetEvent, BpodSystem.StateMachineInfo.EventNames));
if isempty(targetEventCode)
    error(['Error setting global counter. Target event ''' targetEvent ''' is invalid syntax.'])
end

% Set global counter
sma.GlobalCounterThresholds(counterIndex) = threshold;
sma.GlobalCounterEvents(counterIndex) = targetEventCode;
sma.GlobalCounterSet(counterIndex) = 1;
