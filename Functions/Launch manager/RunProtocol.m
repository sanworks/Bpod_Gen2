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

            % Resolve target protocol file
            BpodSystem.Path.ProtocolFolder = BpodSystem.SystemSettings.ProtocolFolder;
            protocolPath = fullfile(BpodSystem.Path.ProtocolFolder, protocolName);
            if ~exist(protocolPath)
                % Look 1 level deeper
                rootContents = dir(BpodSystem.Path.ProtocolFolder);
                nItems = length(rootContents);
                found = 0;
                iFolder = 3;
                while found == 0 && iFolder <= nItems
                    if rootContents(iFolder).isdir
                        protocolPath = fullfile(BpodSystem.Path.ProtocolFolder,... 
                                                rootContents(iFolder).name, protocolName);
                        if exist(protocolPath)
                            found = 1;
                        end
                    end
                    iFolder = iFolder + 1;
                end
            end

            % Throw an error if not found
            if ~exist(protocolPath)
                error(['Error: Protocol "' protocolName '" not found.'])
            end

            % Generate path to protocol file
            protocolRunFile = fullfile(protocolPath, [protocolName '.m']);

            % Verify data path
            dataPath = fullfile(BpodSystem.Path.DataFolder,subjectName);
            if ~exist(dataPath)
                error(['Error starting protocol: Test subject "' subjectName... 
                    '" must be added first, from the launch manager.'])
            end

            %Make standard folders for this protocol.  This will fail silently if the folders exist
            mkdir(dataPath, protocolName);
            mkdir(fullfile(dataPath,protocolName,'Session Data'))
            mkdir(fullfile(dataPath,protocolName,'Session Settings'))
            dateInfo = datestr(now, 30); 
            dateInfo(dateInfo == 'T') = '_';
            fileName = [subjectName '_' protocolName '_' dateInfo '.mat'];
            dataFolder = fullfile(BpodSystem.Path.DataFolder,subjectName,protocolName,'Session Data');
            if ~exist(dataFolder)
                mkdir(dataFolder);
            end
            
            % Ensure that a default settings file exists
            defaultSettingsFilePath = fullfile(dataPath,protocolName,'Session Settings', 'DefaultSettings.mat');
            if ~exist(defaultSettingsFilePath)
                protocolSettings = struct;
                save(defaultSettingsFilePath, 'protocolSettings')
            end
            settingsFileName = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName,... 
                'Session Settings', [settingsName '.mat']);
            if ~exist(settingsFileName)
                error(['Error: Settings file: ' settingsName '.mat does not exist for test subject: '... 
                    subjectName ' in protocol: ' protocolName '.'])
            end
            
            % On Bpod r2+, if FlexIO channels are configured as analog, setup data file
            nAnalogChannels = sum(BpodSystem.HW.FlexIO_ChannelTypes == 2);
            if nAnalogChannels > 0
                analogFilename = [subjectName '_' protocolName '_' dateInfo '_ANLG.dat'];
                if BpodSystem.Status.RecordAnalog == 1
                    BpodSystem.AnalogDataFile = fopen(analogFilename,'w');
                    if BpodSystem.AnalogDataFile == -1
                        error(['Error: Could not open the analog data file: ' analogFilename])
                    end
                end
                BpodSystem.Status.nAnalogSamples = 0;
            end
            
            % Set BpodSystem status, protocol and path fields for new session
            BpodSystem.Status.Live = 1;
            BpodSystem.Status.LastEvent = 0;
            BpodSystem.GUIData.ProtocolName = protocolName;
            BpodSystem.GUIData.SubjectName = subjectName;
            BpodSystem.GUIData.SettingsFileName = settingsFileName;
            BpodSystem.Path.Settings = settingsFileName;
            BpodSystem.Path.CurrentDataFile = fullfile(dataFolder, fileName);
            BpodSystem.Status.CurrentProtocolName = protocolName;
            BpodSystem.Status.CurrentSubjectName = subjectName;
            SettingStruct = load(BpodSystem.Path.Settings);
            f = fieldnames(SettingStruct);
            fieldName = f{1};
            BpodSystem.ProtocolSettings = eval(['SettingStruct.' fieldName]);

            % Clear BpodSystem.Data
            BpodSystem.Data = struct;
            
            % Setup Flex I/O Analog Input data fields
            if BpodSystem.MachineType > 3
                if nAnalogChannels > 0
                    % Setup analog data struct
                    BpodSystem.Data.Analog = struct;
                    BpodSystem.Data.Analog.info = struct;
                    BpodSystem.Data.Analog.FileName = analogFilename;
                    BpodSystem.Data.Analog.nChannels = nAnalogChannels;
                    BpodSystem.Data.Analog.channelNumbers = find(BpodSystem.HW.FlexIO_ChannelTypes == 2);
                    BpodSystem.Data.Analog.SamplingRate = BpodSystem.HW.FlexIO_SamplingRate;
                    BpodSystem.Data.Analog.nSamples = 0;

                    % Add human-readable info about data fields to 'info struct
                    BpodSystem.Data.Analog.info.FileName = 'Complete path and filename of the binary file to which the raw data was logged';
                    BpodSystem.Data.Analog.info.nChannels = 'The number of Flex I/O channels configured as analog input';
                    BpodSystem.Data.Analog.info.channelNumbers = 'The indexes of Flex I/O channels configured as analog input';
                    BpodSystem.Data.Analog.info.SamplingRate = 'The sampling rate of the analog data. Units = Hz';
                    BpodSystem.Data.Analog.info.nSamples = 'The total number of analog samples captured during the behavior session';
                    BpodSystem.Data.Analog.info.Samples = 'Analog measurements captured. Rows are separate analog input channels. Units = Volts';
                    BpodSystem.Data.Analog.info.Timestamps = 'Time of each sample (computed from sample index and sampling rate)';
                    BpodSystem.Data.Analog.info.TrialNumber = 'Experimental trial during which each analog sample was captured';
                    BpodSystem.Data.Analog.info.TrialData = 'A cell array of Samples. Each cell contains samples captured during a single trial.';
                end
            end

            % Add protocol folder to the path
            addpath(protocolRunFile);

            % Set console GUI run button
            set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');
            
            % Send metadata to Bpod Phone Home program (disabled pending a more stable server)
            % isOnline = BpodSystem.check4Internet();
            % if (isOnline == 1) && (BpodSystem.SystemSettings.PhoneHome == 1)
                %BpodSystem.BpodPhoneHome(1); % Disabled until server migration. -JS July 2018
            % end

            % Disable analog viewer record button (fixed for session)
            if BpodSystem.Status.AnalogViewer
                set(BpodSystem.GUIHandles.RecordButton, 'Enable', 'off')
            end

            % Clear console GUI fields
            set(BpodSystem.GUIHandles.CurrentStateDisplay, 'String', '---');
            set(BpodSystem.GUIHandles.PreviousStateDisplay, 'String', '---');
            set(BpodSystem.GUIHandles.LastEventDisplay, 'String', '---');
            set(BpodSystem.GUIHandles.TimeDisplay, 'String', '0:00:00');

            % Set BpodSystem status flags
            BpodSystem.Status.BeingUsed = 1;
            BpodSystem.Status.SessionStartFlag = 1;

            % Record session start time
            BpodSystem.ProtocolStartTime = now*100000;

            % Push console GUI to top and run protocol file
            figure(BpodSystem.GUIHandles.MainFig);
            run(protocolRunFile);
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