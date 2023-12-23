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

function behaviorPortTest(obj)
% BEHAVIOR PORT TEST FUNCTION
%
% This method is designed to conduct a series of tests on behavior ports
% of a connected Bpod state machine. It performs an automated test sequence to verify
% operation of LEDs, valves, and sensor inputs associated with each port. 
% The function iterates through each port defined in the BpodSystem object and performs
% a set of tests including LED functionality, valve operation, port entry
% detection, and false entry detection. The function prompts the user with
% manual operation steps where necessary, and for confirmation of hardware changes.

global BpodSystem % Access the global BpodSystem variable

testPass = 1;  % Initialize testPass flag as 1 (true)

% Define test durations (in seconds)
PortTestDuration = 3;
LEDStateDuration = 0.3;
ValveStateDuration = 0.01;
PauseStateDuration = 0.6;
PortDetectTimeout = 10;

% Display initial test instructions
obj.dispAndLog(' ');
obj.dispAndLog('Starting: Behavior Port Test.');
disp('***IMPORTANT*** Manual operation required.');
obj.dispAndLog(' ');
obj.dispAndLog('Attach a behavior port to port channel 1.');
obj.dispAndLog('When prompted, watch the port for 3s to');
obj.dispAndLog('verify operation of each function.');
obj.dispAndLog(' ');

% Iterate through tests for each port
for p = 1:BpodSystem.HW.n.Ports
    disp(['Ensure that a behavior port is connected to port channel ' num2str(p) '.'])
    % LED Test
    sma = NewStateMachine();
    sma = SetGlobalTimer(sma, 1, PortTestDuration);
    sma = AddState(sma, 'Name', 'StartTimer', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'PortLED'},...
        'OutputActions', {'GlobalTimerTrig', 1});
    sma = AddState(sma, 'Name', 'PortLED', ...
        'Timer', LEDStateDuration,...
        'StateChangeConditions', {'Tup', 'Delay', 'GlobalTimer1_End', '>exit'},...
        'OutputActions', {['PWM' num2str(p)], 255});
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', PauseStateDuration,...
        'StateChangeConditions', {'Tup', 'PortLED', 'GlobalTimer1_End', '>exit'},...
        'OutputActions', {});
    SendStateMachine(sma);
    input(['Testing Port ' num2str(p) ' LED. Press enter to start >']);
    RunStateMachine;
    reply = input('Did the port LED flash? (y/n) > ', 's');
    if ~strcmp(lower(reply), 'y')
        testPass = 0;
        obj.dispAndLog(['*** Error: Port ' num2str(p) ' LED Failed to Operate.'])
    else
        obj.dispAndLog(['Port ' num2str(p) ' LED Operation Verified.']);
    end

    % Valve Test
    sma = NewStateMachine();
    sma = SetGlobalTimer(sma, 1, PortTestDuration);
    sma = AddState(sma, 'Name', 'StartTimer', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'PortValve'},...
        'OutputActions', {'GlobalTimerTrig', 1});
    sma = AddState(sma, 'Name', 'PortValve', ...
        'Timer', ValveStateDuration,...
        'StateChangeConditions', {'Tup', 'Delay', 'GlobalTimer1_End', '>exit'},...
        'OutputActions', {['Valve' num2str(p)], 1});
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', PauseStateDuration,...
        'StateChangeConditions', {'Tup', 'PortValve', 'GlobalTimer1_End', '>exit'},...
        'OutputActions', {});
    SendStateMachine(sma);
    input(['Testing Port ' num2str(p) ' Valve. Press enter to start >']);
    RunStateMachine;
    reply = input('Did the port valve operate? (y/n) > ', 's');
    if ~strcmp(lower(reply), 'y')
        testPass = 0;
        obj.dispAndLog(['*** Error: Port ' num2str(p) ' Valve Failed to Open.'])
    else
        obj.dispAndLog(['Port ' num2str(p) ' Valve Operation Verified.']);
    end

    % Enable port sensor
    PortEnabled_Temp = BpodSystem.InputsEnabled(BpodSystem.HW.Pos.Input_Port+p-1);
    BpodSystem.InputsEnabled(BpodSystem.HW.Pos.Input_Port+p-1) = 1; % Enable port
    UpdatePortEnable; % Local function to update the device with new port enable/disable config

    % Port entry test
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'WaitForPortEntry', ...
        'Timer', PortDetectTimeout,...
        'StateChangeConditions', {'Tup', '>exit', ['Port' num2str(p) 'In'], '>exit'},...
        'OutputActions', {});
    SendStateMachine(sma);
    input(['Testing Port ' num2str(p) ' Entry Detection. Press enter to start >']);
    disp(['Manually enter port ' num2str(p) '. If not detected, the test will end in '...
        num2str(PortDetectTimeout) ' seconds.'])
    RawEvents = RunStateMachine;
    if sum(RawEvents.Events == BpodSystem.HW.Pos.Event_Port+((p-1)*2)) == 0
        testPass = 0;
        obj.dispAndLog(['*** Error: Port ' num2str(p) ' Failed to Detect Entry.'])
    else
        obj.dispAndLog(['Port ' num2str(p) ' Entry Detection Verified.']);
    end

    % Test for false detections
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'WaitForPortEntry', ...
        'Timer', PortDetectTimeout,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {});
    SendStateMachine(sma);
    input(['Testing For Port ' num2str(p) ' False Detections. Press enter to start >']);
    disp(['DO NOT enter port ' num2str(p) ' for ' num2str(PortDetectTimeout) ' seconds. Please wait.'])
    RawEvents = RunStateMachine;
    nEntriesDetected = sum(RawEvents.Events == BpodSystem.HW.Pos.Event_Port+((p-1)*2));
    ErrorMsg = [];
    if nEntriesDetected > 0
        testPass = 0;
        ErrorMsg = '*** Error: ';
    end
    obj.dispAndLog([ErrorMsg 'Port ' num2str(p) ': ' num2str(nEntriesDetected)...
        ' False Entry Detections in ' num2str(PortDetectTimeout) ' Seconds.']);

    % Restore status of port sensor
    BpodSystem.InputsEnabled(BpodSystem.HW.Pos.Input_Port+p-1) = PortEnabled_Temp; % Restore port enable/disable setting
    UpdatePortEnable;
    obj.dispAndLog(' ');
end

% Print test pass/fail
if testPass
    obj.dispAndLog('Behavior Port Test Passed.');
else
    obj.dispAndLog('Behavior Port Test Failed.');
end
end

function UpdatePortEnable
global BpodSystem
BpodSystem.SerialPort.write(['E' BpodSystem.InputsEnabled], 'uint8');
Confirmed = BpodSystem.SerialPort.read(1, 'uint8');
if Confirmed ~= 1
    error('Could not enable ports');
end
end