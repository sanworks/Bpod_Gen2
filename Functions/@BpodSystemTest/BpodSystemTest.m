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
            obj.SoftwareVersion = BpodSoftwareVersion_Semantic;
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
            obj.stateMachineExtensionTest;
            obj.rapidEventTest;
            obj.psRAMTest;
            obj.behaviorPortTest;
        end

        function showTests(obj)
            disp('stateTransitionTest: Cycles through 255 states, verifies that all were passed through.')
            disp('metaFunctionTest: Verifies global timer, global counter and condition functionality.')
            disp('rapidEventTest: Ensures data integrity during rapid events (10kHz) with rapid state transitions (5kHz).')
            disp('psRAMTest: Tests the external PSRAM IC on Bpod State Machine r2+. Test skipped on other models.')
            disp('behaviorPortTest: Verifies functionality of all behavior port channels. Test requires manual operation.')
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