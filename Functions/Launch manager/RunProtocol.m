function RunProtocol(Opstring, varargin)
% RunProtocol() is the starting point for running a Bpod experimental session.
%
% Usage:
% RunProtocol('Start') - Loads the launch manager
% RunProtocol('Start', 'protocolName', 'subjectName', ['settingsName']) - Runs
%    the protocol "protocolName". subjectName is required. settingsName is
%    optional. All 3 are names as they would appear in the launch manager
%    (i.e. do not include full path or file extension).
% RunProtocol('StartStop') - Loads the launch manager if no protocol is
%     running, pauses the protocol if one is running
% RunProtocol('Stop') - Stops the currently running protocol. Data from the
%     partially completed trial is discarded.
%
% Arguments
% ---------
% Opstring : char
%     The operation to perform. Can be: 'Start', 'StartPause', 'Stop'

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

global BpodSystem % Import the global BpodSystem object

% Verify that Bpod is running
if isempty(BpodSystem)
    error('You must run Bpod() before launching a protocol.')
end

switch Opstring
    case 'Start'
        % Starts a new behavior session
        if nargin == 1
            LaunchManager;
        else
            % Read user variables
            protocolName = varargin{1};
            subjectName = varargin{2};
            if nargin > 3
                settingsName = varargin{3};
            else
                settingsName = 'DefaultSettings';
            end

            % Push console GUI to top and run protocol file
            figure(BpodSystem.GUIHandles.MainFig);
            BpodLib.launcher.launchProtocol(BpodSystem, protocolName, subjectName, 'settingsName', settingsName)
        end
    case 'StartPause'
        % Toggles to start or pause the session
        if BpodSystem.Status.BeingUsed == 0
            if BpodSystem.EmulatorMode == 0
                BpodSystem.StopModuleRelay;
            end
            LaunchManager;
        else
            if BpodSystem.Status.Pause == 0
                disp('Pause requested. The system will pause after the current trial completes.')
                BpodSystem.Status.Pause = 1;
                set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseRequestedButton,... 
                    'TooltipString', 'Pause scheduled after trial end'); 
            else
                disp('Session resumed.')
                BpodSystem.Status.Pause = 0;
                set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton,... 
                    'TooltipString', 'Press to pause session');
            end
        end
    case 'Stop'
        % Manually ends the session. The partially completed trial is not saved with the data.
        BpodLib.launcher.stopProtocol(BpodSystem);
end