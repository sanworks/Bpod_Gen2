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

function state_transition_test(obj)
% STATE TRANSITION TEST
%
% This test cycles through 255 states, verifies that all were passed 
% through. State visits verified by list of states returned, and 
% confirmed by number of BNC toggles captured.

global BpodSystem % Import the global BpodSystem object

testPass = 1;  % Initialize testPass flag as 1 (true)

% Display test information
obj.dispAndLog(' ');
obj.dispAndLog('Starting: State Transition Test.');

% Repeat the test multiple times
nTestIterations = 10;
for i = 1:nTestIterations
    BNClevel = 1;
    % Setup the state machine description for the test
    sma = NewStateMachine;
    for x = 1:254
        eval(['sma = AddState(sma, ''Name'', ''State ' num2str(x)...
            ''', ''Timer'', .001, ''StateChangeConditions'', {''Tup'', ''State ' num2str(x+1)...
            '''}, ''OutputActions'', {''BNC1'', ' num2str(BNClevel) '});']);
        BNClevel = 1-BNClevel;
    end
    sma = AddState(sma, 'Name', 'State 255', 'Timer', .001, 'StateChangeConditions', {'Tup', '>exit'}, 'OutputActions', {'BNC1', BNClevel});
    
    % Send the description and run the test
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;

    % Analyze results
    if sum(RawEvents.Events == BpodSystem.HW.StateTimerPosition) ~= 255
        testPass = 0;
        obj.dispAndLog('Error: Test FAILED. Incorrect event(s) detected.')
    end
    if sum(RawEvents.States ~= 1:255) > 0
        testPass = 0;
        obj.dispAndLog('Error: Test FAILED. Incorrect state(s) detected.')
    end
    if sum(RawEvents.Events == BpodSystem.HW.Pos.Event_BNC) ~= 128 || sum(RawEvents.Events == BpodSystem.HW.Pos.Event_BNC+1) ~= 127
        testPass = 0;
        obj.dispAndLog('Error: Test FAILED. Incorrect number of state transitions measured.')
    end
end
if testPass
    obj.dispAndLog('State Transition Test Passed.');
else
    obj.dispAndLog('State Transition Test Failed.');
end
end