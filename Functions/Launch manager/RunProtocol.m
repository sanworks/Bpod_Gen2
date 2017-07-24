%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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
global BpodSystem
switch Opstring
    case 'Start'
        if nargin == 1
            NewLaunchManager;
        else
            protocolName = varargin{1};
            subjectName = varargin{2};
            if nargin > 3
                settingsName = varargin{3};
            else
                settingsName = 'DefaultSettings';
            end
            BpodSystem.Path.ProtocolFolder = BpodSystem.SystemSettings.ProtocolFolder;
            ProtocolPath = fullfile(BpodSystem.Path.ProtocolFolder, protocolName);
            if ~exist(ProtocolPath)
                % Look 1 level deeper
                RootContents = dir(BpodSystem.Path.ProtocolFolder);
                nItems = length(RootContents);
                Found = 0;
                y = 3;
                while Found == 0 && y <= nItems
                    if RootContents(y).isdir
                        ProtocolPath = fullfile(BpodSystem.Path.ProtocolFolder, RootContents(y).name, protocolName);
                        if exist(ProtocolPath)
                            Found = 1;
                        end
                    end
                    y = y + 1;
                end
            end
            if ~exist(ProtocolPath)
                error(['Error: Protocol "' protocolName '" not found.'])
            end
            ProtocolRunFile = fullfile(ProtocolPath, [protocolName '.m']);
            DataPath = fullfile(BpodSystem.Path.DataFolder,subjectName);
            if ~exist(DataPath)
                error(['Error starting protocol: Test subject "' subjectName '" must be added first, from the launch manager.'])
            end
            %Make standard folders for this protocol.  This will fail silently if the folders exist
            mkdir(DataPath, protocolName);
            mkdir(fullfile(DataPath,protocolName,'Session Data'))
            mkdir(fullfile(DataPath,protocolName,'Session Settings'))
            DateInfo = datestr(now, 30); 
            DateInfo(DateInfo == 'T') = '_';
            FileName = [subjectName '_' protocolName '_' DateInfo '.mat'];
            DataFolder = fullfile(BpodSystem.Path.DataFolder,subjectName,protocolName,'Session Data');
            if ~exist(DataFolder)
                mkdir(DataFolder);
            end
            
            % Ensure that a default settings file exists
            DefaultSettingsFilePath = fullfile(DataPath,protocolName,'Session Settings', 'DefaultSettings.mat');
            if ~exist(DefaultSettingsFilePath)
                ProtocolSettings = struct;
                save(DefaultSettingsFilePath, 'ProtocolSettings')
            end
            SettingsFileName = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName, 'Session Settings', [settingsName '.mat']);
            if ~exist(SettingsFileName)
                error(['Error: Settings file: ' settingsName '.mat does not exist for test subject: ' subjectName ' in protocol: ' protocolName '.'])
            end
            BpodSystem.Status.Live = 1;
            BpodSystem.GUIData.ProtocolName = protocolName;
            BpodSystem.GUIData.SubjectName = subjectName;
            BpodSystem.GUIData.SettingsFileName = SettingsFileName;
            BpodSystem.Path.Settings = SettingsFileName;
            BpodSystem.Path.CurrentDataFile = fullfile(DataFolder, FileName);
            BpodSystem.Status.CurrentProtocolName = protocolName;
            BpodSystem.Status.CurrentSubjectName = subjectName;
            SettingStruct = load(BpodSystem.Path.Settings);
            F = fieldnames(SettingStruct);
            FieldName = F{1};
            BpodSystem.ProtocolSettings = eval(['SettingStruct.' FieldName]);
            BpodSystem.Data = struct;
            addpath(ProtocolRunFile);
            set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');
            BpodSystem.Status.BeingUsed = 1;
            BpodSystem.ProtocolStartTime = now*100000;
            figure(BpodSystem.GUIHandles.MainFig);
            run(ProtocolRunFile);
        end
    case 'StartPause'
        if BpodSystem.Status.BeingUsed == 0
            if BpodSystem.EmulatorMode == 0
                BpodSystem.StopModuleRelay;
            end
            NewLaunchManager;
        else
            if BpodSystem.Status.Pause == 0
                disp('Pause requested. The system will pause after the current trial completes.')
                BpodSystem.Status.Pause = 1;
                set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseRequestedButton, 'TooltipString', 'Pause scheduled after trial end'); 
            else
                disp('Session resumed.')
                BpodSystem.Status.Pause = 0;
                set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');
            end
        end
    case 'Stop'
        if ~isempty(BpodSystem.Status.CurrentProtocolName)
            disp(' ')
            disp([BpodSystem.Status.CurrentProtocolName ' ended.'])
        end
        rmpath(fullfile(BpodSystem.Path.ProtocolFolder, BpodSystem.Status.CurrentProtocolName));
        BpodSystem.Status.BeingUsed = 0;
        BpodSystem.Status.CurrentProtocolName = '';
        BpodSystem.Path.Settings = '';
        BpodSystem.Status.Live = 0;
        if BpodSystem.EmulatorMode == 0
            BpodSystem.SerialPort.write('X', 'uint8');
            pause(.1);
            nBytes = BpodSystem.SerialPort.bytesAvailable;
            if nBytes > 0
                BpodSystem.SerialPort.read(nBytes, 'uint8');
            end
            if isfield(BpodSystem.PluginSerialPorts, 'TeensySoundServer')
                TeensySoundServer('end');
            end   
        end
        BpodSystem.Status.InStateMatrix = 0;
        % Shut down protocol and plugin figures (should be made more general)
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
        catch
        end
        set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.GoButton, 'TooltipString', 'Launch behavior session');
        if BpodSystem.Status.Pause == 1
            BpodSystem.Status.Pause = 0;
        end
        % ---- end Shut down Plugins
end