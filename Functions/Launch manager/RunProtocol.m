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

% RunProtocol() is the starting point for running a Bpod experimental session.

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

function RunProtocol(Opstring, varargin)

global BpodSystem % Import the global BpodSystem object

% Verify that Bpod is running
if isempty(BpodSystem)
    error('You must run Bpod() before launching a protocol.')
end

switch Opstring
    case 'Start'
        % Starts a new behavior session
        if nargin == 1
            NewLaunchManager;
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
            BpodLib.launcher.launchProtocol(BpodSystem, protocolName, subjectName, settingsName)
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
        if ~isempty(BpodSystem.Status.CurrentProtocolName)
            disp(' ')
            disp([BpodSystem.Status.CurrentProtocolName ' ended'])
        end
        warning off % Suppress warning, in case protocol folder has already been removed
        rmpath(fullfile(BpodSystem.Path.ProtocolFolder, BpodSystem.Status.CurrentProtocolName));
        warning on
        BpodSystem.Status.BeingUsed = 0;
        BpodSystem.Status.CurrentProtocolName = '';
        BpodSystem.Path.Settings = '';
        BpodSystem.Status.Live = 0;
        if BpodSystem.EmulatorMode == 0
            if BpodSystem.MachineType > 3
                stop(BpodSystem.Timers.AnalogTimer);
                try
                fclose(BpodSystem.AnalogDataFile);
                catch
                end
            end
            BpodSystem.SerialPort.write('X', 'uint8');
            pause(.1);
            BpodSystem.SerialPort.flush;
            if BpodSystem.MachineType > 3
                BpodSystem.AnalogSerialPort.flush;
            end
            if isfield(BpodSystem.PluginSerialPorts, 'TeensySoundServer')
                TeensySoundServer('end');
            end   
        end
        BpodSystem.Status.RecordAnalog = 1;
        BpodSystem.Status.InStateMatrix = 0;

        % Close protocol and plugin figures
        try
            Figs = fields(BpodSystem.ProtocolFigures);
            nFigs = length(Figs);
            for x = 1:nFigs
                try
                    close(eval(['BpodSystem.ProtocolFigures.' Figs{x}]));
                catch
                    
                end
            end
            try
                close(BpodNotebook)
            catch
            end
            try
                BpodSystem.analogViewer('end', []);
            catch
            end
        catch
        end
        set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.GoButton,... 
            'TooltipString', 'Launch behavior session');
        if BpodSystem.Status.Pause == 1
            BpodSystem.Status.Pause = 0;
        end
        % ---- end Shut down Plugins
end