%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2023 Sanworks LLC, Rochester, New York, USA

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

classdef BpodSystemTest < handle
    % BpodSystemTest - Class for testing the Bpod behavior measurement system
    % Test results will be displayed, and logged in /Bpod Local/System Logs/
    % Usage:
    % Init with: B = BpodSystemTest;
    % Use B.testAll; to run the complete suite of tests.
    % Use B.showTests; to print a list of all tests.
    % Run individual tests with B.myTestName;
    % Use clear B; to end and close the log file.

    properties
        Version = 1;
    end
    properties (Access = private)
        FSM_Model          % Model of the Finite State Machine
        SoftwareVersion    % Version of the Bpod software
        FirmwareVersion    % Firmware version on the connected state machine
        LogFile            % Log file handle
    end
    methods
        function obj = BpodSystemTest()
            global BpodSystem
            if isempty(BpodSystem)
                clear global BpodSystem
                disp(' ')
                input(['**ATTENTION** Bpod must be started to run this test.' char(10) 'Ensure the state machine is connected and press enter to continue.'], 's');
                Bpod;
                global BpodSystem
            end

            % Set up log file
            DateInfo = datestr(now, 30);
            DateInfo(DateInfo == 'T') = '_';
            if ~isdir(fullfile(BpodSystem.Path.LocalDir, 'System Logs'))
                mkdir(fullfile(BpodSystem.Path.LocalDir, 'System Logs'))
            end
            LogFilename = fullfile(BpodSystem.Path.LocalDir, 'System Logs', ['SystemTest_' DateInfo '.txt']);
            obj.LogFile = fopen(LogFilename,'wt');
            if obj.LogFile == -1
                error('Error: Could not open log file.')
            end

            % Print header
            disp(' ');
            obj.dispAndLog('********************')
            obj.dispAndLog('* Bpod System Test *')
            obj.dispAndLog('********************')
            disp(' ')
            disp(['Logging to: ' LogFilename])
            obj.dispAndLog(' ');
            obj.dispAndLog(['Date: ' datestr(now, 1) char(10) 'Time: ' datestr(now, 13)]);
            % Print system, software and PC info
            obj.FSM_Model = BpodSystem.HW.StateMachineModel;
            obj.SoftwareVersion = BpodSoftwareVersion;
            obj.FirmwareVersion = BpodSystem.FirmwareVersion;
            [~,systemview] = memory;
            ptbInstalled = false;
            try
                [~, ptbVersionStructure] = PsychtoolboxVersion;
                ptbInstalled = true;
            catch
                ptbVersionString = '-Not Installed-';
            end
            if ptbInstalled
                ptbVersionString = [num2str(ptbVersionStructure.major) '.'...
                    num2str(ptbVersionStructure.minor) '.'...
                    num2str(ptbVersionStructure.point) ' - Flavor: '...
                    ptbVersionStructure.flavor];
            end
            obj.dispAndLog(' ');
            obj.dispAndLog('BPOD SYSTEM INFO:')
            obj.dispAndLog(['Bpod Software v' num2str(obj.SoftwareVersion)])
            obj.dispAndLog(['State Machine Model: ' obj.FSM_Model])
            obj.dispAndLog(['State Machine Firmware: v' num2str(obj.FirmwareVersion)])
            obj.dispAndLog(' ')
            obj.dispAndLog('SOFTWARE INFO:')
            obj.dispAndLog(['MATLAB version: ' version('-release')])
            obj.dispAndLog(['Psychtoolbox version: ' ptbVersionString])
            obj.dispAndLog(' ')
            obj.dispAndLog('HOST PC INFO:')
            obj.dispAndLog(['PC Architecture: ' computer('arch')])
            obj.dispAndLog(['Operating System: ' BpodSystem.HostOS])
            obj.dispAndLog(['Free System RAM: ' num2str(systemview.PhysicalMemory.Available/1000000000) 'GB'])
            obj.dispAndLog(['Number of CPU Cores: ' getenv('NUMBER_OF_PROCESSORS')])
            obj.dispAndLog(' ');
            disp('INSTRUCTIONS:')
            disp('Init with: B = BpodSystemTest;')
            disp('Use B.testAll; to run the complete suite of tests.')
            disp('Use B.showTests; to view a list of all tests.')
            disp('Run individual tests with B.myTestName;')
            disp('Use clear B; to end.')
            disp(' ');
            input('Connect BNCOut1 --> BNCIn1, BNCOut2 --> BNCIn2 and press enter to continue >', 's');
        end

        function testAll(obj)
            obj.stateTransitionTest;
            obj.metaFunctionTest;
            obj.rapidEventTest;
            obj.behaviorPortTest;
        end

        function showTests(obj)
            disp('stateTransitionTest: Cycles through 255 states, verifies that all were passed through.')
            disp('metaFunctionTest: Verifies global timer, global counter and condition functionality.')
            disp('rapidEventTest: Ensures data integrity during rapid events (10kHz) with rapid state transitions (5kHz).')
            disp('behaviorPortTest: Verifies functionality of all behavior port channels. Test requires manual operation.')
        end

        function stateTransitionTest(obj)
            % Cycles through 255 states, verifies that all were passed through.
            % State visits verified by list of states returned, and state count 
            % confirmed by BNC toggles captured.
            global BpodSystem
            testPass = 1;
            obj.dispAndLog(' ');
            obj.dispAndLog('Starting: State Transition Test.');
            nTestIterations = 10;
            for i = 1:nTestIterations
                BNClevel = 1;
                sma = NewStateMachine;
                for x = 1:254
                    eval(['sma = AddState(sma, ''Name'', ''State ' num2str(x)...
                        ''', ''Timer'', .001, ''StateChangeConditions'', {''Tup'', ''State ' num2str(x+1)...
                        '''}, ''OutputActions'', {''BNC1'', ' num2str(BNClevel) '});']);
                    BNClevel = 1-BNClevel;
                end
                sma = AddState(sma, 'Name', 'State 255', 'Timer', .001, 'StateChangeConditions', {'Tup', '>exit'}, 'OutputActions', {'BNC1', BNClevel});
                SendStateMatrix(sma);
                RawEvents = RunStateMatrix;
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

        function metaFunctionTest(obj)
            global BpodSystem
            testPass = 1;
            obj.dispAndLog(' ');
            obj.dispAndLog('Starting: Meta Function Test.');
            % Two timers (first and last index) are started in state 1. Timers
            % are looping, and attached to BNC1 and BNC2 channels.
            % A global counter attached to BNC1 moves the machine to the next
            % state on reaching 3 counts
            % A condition attached to BNC2_High moves the machine to the final
            % state
            % Event flow is sanity-checked
            nIterations = 10;
            for i = 1:nIterations
                TimerInterval = 0.1;
                TimerDelay = 0.05;
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
                SendStateMatrix(sma);
                RawEvents = RunStateMatrix;
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
                obj.dispAndLog('Meta Function Test Passed.');
            else
                obj.dispAndLog('Meta Function Test Failed.');
            end
        end

        function rapidEventTest(obj)
            global BpodSystem
            stateDuration = 0.0002;
            testDuration = 10;
            obj.dispAndLog(' ');
            obj.dispAndLog('Starting: Rapid Event Test.');
            obj.dispAndLog(['Testing: ' num2str(2*(1/stateDuration)) ' events/sec during ' num2str(1/stateDuration) ' state transitions/sec for ' num2str(testDuration) ' seconds.']);
            obj.dispAndLog('Please Wait...');
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
            SendStateMatrix(sma);
            RawEvents = RunStateMatrix;
            nStatesVisited = length(RawEvents.States(2:end));
            nSeconds = RawEvents.StateTimestamps(end) - RawEvents.StateTimestamps(2);
            statesPerSecond = nStatesVisited/nSeconds;
            BNC1High = BpodSystem.HW.IOEventStartposition;
            BNC1Low = BpodSystem.HW.IOEventStartposition+1;
            BNC2High = BpodSystem.HW.IOEventStartposition+2;
            BNC2Low = BpodSystem.HW.IOEventStartposition+3;
            nEventsCaptured = sum(RawEvents.Events == BNC1High) + sum(RawEvents.Events == BNC1Low) + sum(RawEvents.Events == BNC2High) + sum(RawEvents.Events == BNC2Low);
            nExpectedEvents = floor(2*(1/stateDuration))*testDuration;
            obj.dispAndLog([num2str(nExpectedEvents) ' events expected, ' num2str(nEventsCaptured) ' captured.'])
            if nEventsCaptured == nExpectedEvents
                obj.dispAndLog('Rapid Event Test Passed.');
            else
                obj.dispAndLog('Rapid Event Test Failed!');
            end
        end

        function delete(obj)
            fclose(obj.LogFile);
            obj.LogFile = [];
        end
    end
    methods (Access = private)
        function dispAndLog(obj, msg)
            fwrite(obj.LogFile, [msg char(10)]); % Use char(10) instead of newline for compatibility with r2015b and earlier
            disp(msg);
        end
    end
end