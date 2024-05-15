function launchProtocol(BpodSystem, protocolPointer, subjectName, settingsName, varargin)
% launchProtocol(BpodSystem, protocolPointer, subjectName, settingsName, varargin)
% Launches a protocol for a given subject and settings file
%
% Inputs
% ------
% BpodSystem : BpodObject
%     The Bpod system
% protocolPointer : str
%     The name of the protocol to run
%     Because of ambiguity in names, can be a absolute/relative file path (e.g. 'Protocols/Group1/MyProtocol' or 'Group1/MyProtocol')
% subjectName : str
%     The name of the subject
% settingsName : str
%     The name of the settings file
% varargin : cell
%     Additional arguments to pass to the protocol (i.e. MyProtocol(varargin{:}))

% Generate path to protocol file
protocolRunFile = BpodLib.paths.findProtocolFile(BpodSystem.SystemSettings.ProtocolFolder, protocolPointer);
protocolRunFolder = fileparts(protocolRunFile);
[~, protocolName] = fileparts(protocolRunFile);

% Verify data path
dataFilePath = BpodLib.launcher.createDataFilePath(BpodSystem.Path.DataFolder, protocolName, subjectName);
protocolDataFolder = fileparts(dataFilePath);
if ~exist(protocolDataFolder)
    error(['Error starting protocol: Test subject "' subjectName... 
        '" must be added first, from the launch manager.'])
end


% Ensure that the settings file exists
BpodLib.launcher.createDefaultSettingsFile(BpodSystem.Path.DataFolder, subjectName, protocolName);
settingsFolderPath = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName, 'Session Settings');
candidateSettingsFiles = dir(fullfile(settingsFolderPath, '*.mat'));

settingsFileNames = {candidateSettingsFiles.name};
if ~ismember([settingsName '.mat'], settingsFileNames)
    error(['Error: Settings file: ' settingsName '.mat does not exist for test subject: '... 
        subjectName ' in protocol: ' protocolName '.'])
end
settingsFilePath = fullfile(BpodSystem.Path.DataFolder, subjectName, protocolName,... 
    'Session Settings', [settingsName '.mat']);

% On Bpod r2+, if FlexIO channels are configured as analog, setup data file
nAnalogChannels = sum(BpodSystem.HW.FlexIO_ChannelTypes == 2);
if nAnalogChannels > 0
    analogFilename = [BpodSystem.Path.CurrentDataFile(1:end-4) '_ANLG.dat'];
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
BpodSystem.GUIData.SettingsFileName = settingsFilePath;
BpodSystem.Path.Settings = settingsFilePath;
BpodSystem.Path.CurrentDataFile = dataFilePath;
BpodSystem.Status.CurrentProtocolName = protocolName;
BpodSystem.Status.CurrentSubjectName = subjectName;
settingStruct = load(BpodSystem.Path.Settings);
F = fieldnames(settingStruct);
fieldName = F{1};
BpodSystem.ProtocolSettings = eval(['settingStruct.' fieldName]);

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

% Set console GUI run button
set(BpodSystem.GUIHandles.RunButton, 'cdata', BpodSystem.GUIData.PauseButton, 'TooltipString', 'Press to pause session');

% Send metadata to Bpod Phone Home program (disabled pending a more stable server)
% isOnline = BpodSystem.check4Internet();
% if (isOnline == 1) && (BpodSystem.SystemSettings.PhoneHome == 1)
    % BpodSystem.BpodPhoneHome(1); % Disabled until server migration. -JS July 2018
% end

% Disable analog viewer record button (fixed for session)
if BpodSystem.Status.AnalogViewer
    set(BpodSystem.GUIHandles.RecordButton, 'Enable', 'off')
end

% Set BpodSystem status flags
BpodSystem.Status.BeingUsed = 1;
BpodSystem.Status.SessionStartFlag = 1;

% Record session start time
BpodSystem.ProtocolStartTime = now*100000;
BpodSystem.resetSessionClock();

% Clear console GUI fields
set(BpodSystem.GUIHandles.CurrentStateDisplay, 'String', '---');
set(BpodSystem.GUIHandles.PreviousStateDisplay, 'String', '---');
set(BpodSystem.GUIHandles.LastEventDisplay, 'String', '---');
set(BpodSystem.GUIHandles.TimeDisplay, 'String', '0:00:00');
if sum(BpodSystem.InputsEnabled(BpodSystem.HW.Inputs == 'P')) == 0
    warning(['All Bpod behavior ports are currently disabled.'... 
             'If your protocol requires behavior ports, enable them from the settings menu.'])
end

% Add protocol folder to the path
rmpath(fileparts(BpodSystem.Path.CurrentProtocol))  % this is here because errors might prevent any shutdown procedures from running
addpath(protocolRunFolder);
BpodSystem.Path.CurrentProtocol = protocolRunFile;
% ? could cd into protocolRunFolder instead of adding to path to resolve pathing issues

% Run the protocol!
fprintf('%s Launched protocol: %s\n', datestr(now, 13), protocolRunFile)
if nargin == 4
    % Cleanest easiest behaviour
    run(protocolRunFile);
else
    % If the user requested to pass additional arguments to the protocol
    protocolFuncHandle = str2func(protocolName);
    funcInfo = functions(protocolFuncHandle);
    if ~strcmp(funcInfo.file, protocolRunFile)
        % In this situation the pathing to the protocol is clear within Protocols/ but
        % there may be Path clashes from elsewhere. If the user is savvy enough to
        % pass additional arguments, hopefully they can resolve this issue.
        fprintf('Requested protocol: %s\n', protocolRunFile)
        fprintf('Found protocol:     %s\n', funcInfo.file)
        error('The function handle does not point to the correct file.');
    end
    protocolFuncHandle(varargin{:});
end