%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

----------------------------------------------------------------------------

This program is free software:you can redistribute it and / or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see < http: // www.gnu.org / licenses /> .
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
% RunProtocol('Safe') - Same as RunProtocol('Start'), but will end gracefully in protocol is ended with Ctrl-C or SIGINT event

function RunProtocol(Opstring, varargin)
    global BpodSystem

    if isempty(BpodSystem)
        error('You must run Bpod() before launching a protocol.')
    end

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
                DataPath = fullfile(BpodSystem.Path.DataFolder, subjectName);

                if ~exist(DataPath)
                    error(['Error starting protocol: Test subject "' subjectName '" must be added first, from the launch manager.'])
                end

                %Make standard folders for this protocol.  This will fail silently if the folders exist
                mkdir(DataPath, protocolName);
                mkdir(fullfile(DataPath, protocolName, 'Session Data'))
                mkdir(fullfile(DataPath, protocolName, 'Session Settings'))
                DateInfo = datestr(now, 30);
                DateInfo(DateInfo == 'T') = '_';
                FileName = [subjectName '_' protocolName '_' DateInfo '.mat'];
                DataFolder = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName, 'Session Data');

                if ~exist(DataFolder)
                    mkdir(DataFolder);
                end

                % Ensure that a default settings file exists
                DefaultSettingsFilePath = fullfile(DataPath, protocolName, 'Session Settings', 'DefaultSettings.mat');

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

                if isfield(BpodSystem.GUIHandles, 'MainFig')
                    set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');
                end

                IsOnline = BpodSystem.check4Internet();

                if (IsOnline == 1) && (BpodSystem.SystemSettings.PhoneHome == 1)
                    %BpodSystem.BpodPhoneHome(1); % Disabled until server migration. -JS July 2018
                end

                BpodSystem.Status.BeingUsed = 1;
                BpodSystem.ProtocolStartTime = now * 100000;

                if BpodSystem.ShowGUI && isfield(BpodSystem.GUIHandles, 'MainFig')
                    figure(BpodSystem.GUIHandles.MainFig);
                end

                try
                    run(ProtocolRunFile);
                catch e

                    if strcmp(e.message, 'Reference to non-existent field ''States''.') || strcmp(e.message, 'Unrecognized field name "States".')
                        fprintf("Protocol ended manually.\n");
                    else
                        fprintf("An error occured while running the protocol: \n");

                        for i = 1:length(e.stack)
                            fprintf("Function = %s on line = %d\n", e.stack(i).name, e.stack(i).line);
                        end

                        fprintf('%s; %s\n', e.identifier, e.message);
                    end

                end

            end

        case 'StartSafe'

            % if protocol ended with keyboard interrupt or sigint,
            % uses same ending procedure as RunProtocol('Stop') and **saves data**
            cleanup = onCleanup(@() StopProtocol(true));

            % Run protocol as normal
            if nargin == 1
                RunProtocol('Start');
            else
                protocolName = varargin{1};
                subjectName = varargin{2};

                if nargin > 3
                    settingsName = varargin{3};
                else
                    settingsName = 'DefaultSettings';
                end

                RunProtocol('Start', protocolName, subjectName, settingsName);
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

                    if isfield(BpodSystem.GUIHandles, 'MainFig')
                        set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseRequestedButton, 'TooltipString', 'Pause scheduled after trial end');
                    end

                else
                    disp('Session resumed.')
                    BpodSystem.Status.Pause = 0;

                    if isfield(BpodSystem.GUIHandles, 'MainFig')
                        set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');
                    end

                end

            end

        case 'Stop'

            if nargin > 1
                StopProtocol(varargin{2});
            else
                StopProtocol;
            end

    end
