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

function stateMachineExtensionTest(obj)
% STATE MACHINE EXTENSION TEST
%
% This test verifies the functionality of state machine framework extensions:
% Global Timers, Global Counters and Conditions.
% Two global timers (first and last index) are started in state 1. Timers
% are looping, and attached to BNC1 and BNC2 channels.
% A global counter attached to BNC1 moves the machine to the next
% state on reaching 3 counts
% A condition attached to BNC2_High moves the machine to the final
% state. Event flow is sanity-checked.

global BpodSystem % Access the global BpodSystem variable

testPass = 1;  % Initialize testPass flag as 1 (true)

% Define test durations (in seconds)
TimerInterval = 0.1;
TimerDelay = 0.05;

% Display test information
obj.dispAndLog(' ');
obj.dispAndLog('Starting: Meta Function Test.');

% Repeat the test multiple times
nIterations = 10;
for i = 1:nIterations
    % Setup the state machine description for the test
    sma = NewStateMachine;
    sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', TimerInterval, 'OnsetDelay', 0,...
        'Channel', 'BNC1', 'OnEvent', 1, 'OffEvent', 0,...
        'Loop', 1, 'SendGlobalTimerEvents', 1, 'LoopInterval', TimerInterval);
    sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', 3, 'OnsetDelay', 0);
    sma = SetGlobalTimer(sma, 'TimerID', BpodSystem.HW.n.GlobalTimers, 'Duration', TimerInterval, 'OnsetDelay', TimerDelay,...
        'Channel', 'BNC2', 'OnEvent', 1, 'OffEvent', 0,...
        'Loop', 1, 'SendGlobalTimerEvents', 1, 'LoopInterval', TimerInterval);
    sma = SetGlobalCounter(sma, 1, 'BNC1High', 3);
    sma = SetCondition(sma, 2, 'BNC2', 1);
    sma = AddState(sma, 'Name', 'TimerTrig', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'WaitForCounter'},...
        'OutputActions', {'GlobalTimerTrig', ['1' char(ones(1,BpodSystem.HW.n.GlobalTimers-3))*48 '11']});
    sma = AddState(sma, 'Name', 'WaitForCounter', ...
        'Timer', 0,...
        'StateChangeConditions', {'GlobalCounter1_End', 'WaitForCondition', 'GlobalTimer2_End', 'Timeout'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'WaitForCondition', ...
        'Timer', 0,...
        'StateChangeConditions', {'Condition2', '>exit', 'GlobalTimer2_End', 'Timeout'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Timeout', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {});

    % Send the description and run the test
    SendStateMatrix(sma);
    RawEvents = RunStateMachine;
    
    % Analyze results
    if sum(RawEvents.States == find(strcmp(BpodSystem.StateMatrixSent.StateNames, 'Timeout')))>0
        testPass = 0;
        obj.dispAndLog('Error: Test FAILED. A Condition was not registered.');
    end
    if RawEvents.States ~= 1:BpodSystem.StateMatrixSent.nStatesInManifest-1
        testPass = 0;
        obj.dispAndLog('Error: Test FAILED. Incorrect state flow detected.')
    end
    GlobalCounterEnd = find(strcmp(BpodSystem.StateMachineInfo.EventNames, 'GlobalCounter1_End'));
    ConditionEvent = find(strcmp(BpodSystem.StateMachineInfo.EventNames, 'Condition2'));
    if find(RawEvents.Events == GlobalCounterEnd) > find(RawEvents.Events == ConditionEvent)
        testPass = 0;
        obj.dispAndLog('Error: Test FAILED. Incorrect event sequence detected.')
    end
    BNC1High = find(strcmp(BpodSystem.StateMachineInfo.EventNames, 'BNC1High'));
    BNC1Low = find(strcmp(BpodSystem.StateMachineInfo.EventNames, 'BNC1Low'));
    BNC2High = find(strcmp(BpodSystem.StateMachineInfo.EventNames, 'BNC2High'));
    BNC2Low = find(strcmp(BpodSystem.StateMachineInfo.EventNames, 'BNC2Low'));
    BNC1HighTimes = RawEvents.EventTimestamps(RawEvents.Events == BNC1High);
    BNC1LowTimes = RawEvents.EventTimestamps(RawEvents.Events == BNC1Low);
    BNC2HighTimes = RawEvents.EventTimestamps(RawEvents.Events == BNC2High);
    BNC2LowTimes = RawEvents.EventTimestamps(RawEvents.Events == BNC2Low);
    CyclePeriod = 1/BpodSystem.HW.CycleFrequency;
    if sum(round(diff(BNC1HighTimes)*10000)/10000 == 2*TimerInterval)~=length(BNC1HighTimes)-1 || abs(BNC1HighTimes(1) - CyclePeriod) > 0.00001
        testPass = 0;
        obj.dispAndLog('Error: BNC1High events occurred out of sequence')
    end
    if sum(round(diff(BNC1LowTimes)*10000)/10000 == 2*TimerInterval)~=length(BNC1LowTimes)-1 || abs(BNC1LowTimes(1) - (TimerInterval + CyclePeriod)) > 0.00001
        testPass = 0;
        obj.dispAndLog('Error: BNC1Low events occurred out of sequence')
    end
    if sum(round(diff(BNC2HighTimes)*10000)/10000 == 2*TimerInterval)~=length(BNC2HighTimes)-1 || abs(BNC2HighTimes(1) - (TimerDelay + CyclePeriod)) > 0.00001
        testPass = 0;
        obj.dispAndLog('Error: BNC2High events occurred out of sequence')
    end
    if sum(round(diff(BNC2LowTimes)*10000)/10000 == 2*TimerInterval)~=length(BNC2LowTimes)-1 || abs(BNC2LowTimes(1) - (TimerInterval+TimerDelay+CyclePeriod)) > 0.00001
        testPass = 0;
        obj.dispAndLog('Error: BNC2Low events occurred out of sequence')
    end
end
if testPass
    obj.dispAndLog('State Machine Extension Test Passed.');
else
    obj.dispAndLog('State Machine Extension Test Failed.');
end
end