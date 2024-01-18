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

function rapid_event_test(obj)
% RAPID EVENT TEST FUNCTION
%
% This method is designed to test the performance of the Bpod state machine
% under load. Rapid state changes are combined with rapid behavioral events
% captured via BNC loopback. The resulting data is checked for consistency 
% and data loss.

global BpodSystem % Import the global BpodSystem object

% Define test durations (in seconds)
stateDuration = 0.0002;
testDuration = 10;

% Display test information
obj.dispAndLog(' ');
obj.dispAndLog('Starting: Rapid Event Test.');
obj.dispAndLog(['Testing: ' num2str(2*(1/stateDuration)) ' events/sec during ' num2str(1/stateDuration) ' state transitions/sec for ' num2str(testDuration) ' seconds.']);
obj.dispAndLog('Please Wait...');

% Setup the state machine description for the test
sma = NewStateMachine();
sma = SetGlobalTimer(sma, 1, testDuration);
sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', stateDuration, 'OnsetDelay', 0,...
    'Channel', 'BNC1', 'OnLevel', 1, 'OffLevel', 0,...
    'Loop', 1, 'SendGlobalTimerEvents', 0, 'LoopInterval', stateDuration);
sma = SetGlobalTimer(sma, 'TimerID', 3, 'Duration', stateDuration, 'OnsetDelay', 0,...
    'Channel', 'BNC2', 'OnLevel', 1, 'OffLevel', 0,...
    'Loop', 1, 'SendGlobalTimerEvents', 0, 'LoopInterval', stateDuration);
sma = AddState(sma, 'Name', 'TimerTrig', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'Port1Lit'},...
    'OutputActions', {'GlobalTimerTrig', '111'});
sma = AddState(sma, 'Name', 'Port1Lit', ...
    'Timer', stateDuration,...
    'StateChangeConditions', {'Tup', 'Port3Lit', 'GlobalTimer1_End', '>exit'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'Port3Lit', ...
    'Timer', stateDuration,...
    'StateChangeConditions', {'Tup', 'Port1Lit', 'GlobalTimer1_End', '>exit'},...
    'OutputActions', {});

% Send the description and run the test
SendStateMatrix(sma);
RawEvents = RunStateMachine;

% Analyze results
nStatesVisited = length(RawEvents.States(2:end));
nSeconds = RawEvents.StateTimestamps(end) - RawEvents.StateTimestamps(2);
statesPerSecond = nStatesVisited/nSeconds;
bnc1High = BpodSystem.HW.IOEventStartposition;
bnc1Low = BpodSystem.HW.IOEventStartposition+1;
bnc2High = BpodSystem.HW.IOEventStartposition+2;
bnc2Low = BpodSystem.HW.IOEventStartposition+3;
nEventsCaptured = sum(RawEvents.Events == bnc1High) + sum(RawEvents.Events == bnc1Low) + sum(RawEvents.Events == bnc2High)... 
                  + sum(RawEvents.Events == bnc2Low);
nExpectedEvents = floor(2*(1/stateDuration))*testDuration;
obj.dispAndLog([num2str(nExpectedEvents) ' events expected, ' num2str(nEventsCaptured) ' captured.'])
if nEventsCaptured == nExpectedEvents
    obj.dispAndLog('Rapid Event Test Passed.');
else
    obj.dispAndLog('Rapid Event Test Failed!');
end
end