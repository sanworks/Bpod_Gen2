function legacyPathInit(obj, varargin)
% legacyPathInit - Initialisation component of BpodObject setup from 1.8.1
% inputParser modifications were written to enable testing

p = inputParser();
p.addParameter('verbose', false)  % this would have been true in 1.8.1 (the calibration file dialogue box)
p.addParameter('LocalDir', "")
p.parse(varargin{:})

% Initialize paths
obj.Path = struct;
obj.Path.BpodRoot = bpodPath;
obj.Path.ParentDir = fileparts(bpodPath);
if isempty(p.Results.LocalDir)
    obj.Path.LocalDir = fullfile(obj.Path.ParentDir, 'Bpod Local');
else
    obj.Path.LocalDir = fullfile(p.Results.LocalDir);
end
obj.Path.SettingsDir = fullfile(obj.Path.LocalDir, 'Settings');
obj.Path.Settings = '';
obj.Path.DataFolder = '';
obj.Path.CurrentDataFile = '';
obj.Path.CurrentProtocol= '';
obj.Path.InputConfig = fullfile(obj.Path.SettingsDir, 'InputConfig.mat');
obj.Path.FlexConfig = fullfile(obj.Path.SettingsDir, 'FlexConfig.mat');
obj.Path.SyncConfig = fullfile(obj.Path.SettingsDir, 'SyncConfig.mat');
obj.Path.ModuleUSBConfig = fullfile(obj.Path.SettingsDir, 'ModuleUSBConfig.mat');

% Ensure that settings, data, protocol and calibration folders exist
if ~exist(obj.Path.LocalDir)
    mkdir(obj.Path.LocalDir);
end
if ~exist(obj.Path.SettingsDir)
    mkdir(obj.Path.SettingsDir);
end
addpath(genpath(obj.Path.SettingsDir));
if exist('BpodSettings.mat') > 0
    load BpodSettings;
    obj.SystemSettings = BpodSettings;
else
    obj.SystemSettings = struct;
end
obj.Path.ProtocolFolder = '';
if isfield(obj.SystemSettings, 'ProtocolFolder')
    if exist(obj.SystemSettings.ProtocolFolder)
        obj.Path.ProtocolFolder = obj.SystemSettings.ProtocolFolder;
    end
end
obj.Path.DataFolder = '';
if isfield(obj.SystemSettings, 'DataFolder')
    if exist(obj.SystemSettings.DataFolder)
        obj.Path.DataFolder = obj.SystemSettings.DataFolder;
    end
end
obj.Path.BcontrolRootFolder = '';
if isfield(obj.SystemSettings, 'BcontrolRootFolder')
    if exist(obj.SystemSettings.BcontrolRootFolder) == 7
        obj.Path.BcontrolRootFolder = obj.SystemSettings.BcontrolRootFolder;
        ExperPortFolder = fullfile(obj.Path.BcontrolRootFolder, 'ExperPort');
        if exist(ExperPortFolder) == 7
            addpath(ExperPortFolder);
        end
    end
end

% Verify calibration folder and copy example calibration if none exist
% (so that users can validate the system and develop protocols before running calibration)
calFolder = fullfile(obj.Path.LocalDir,'Calibration Files');
if ~exist(calFolder)
    mkdir(calFolder);
    % todo: this could be JSON?
    copyfile(fullfile(obj.Path.BpodRoot, 'Examples', 'Example Calibration Files'), calFolder);
    if p.Results.verbose
        questdlg('Calibration folder created in /BpodLocal/. Replace example calibration files soon.', ...
            'Calibration folder not found', ...
            'Ok', 'Ok');
    end
end

% Load liquid calibration
 % Load liquid calibration
 try
    liquidCalibrationFilePath = fullfile(obj.Path.LocalDir, 'Calibration Files', 'LiquidCalibration.mat');
    load(liquidCalibrationFilePath);
    obj.CalibrationTables.LiquidCal = LiquidCal;
catch
    obj.CalibrationTables.LiquidCal = [];
end

% Load sound calibration
try
    soundCalibrationFilePath = fullfile(obj.Path.LocalDir, 'Calibration Files', 'SoundCalibration.mat');
    load(soundCalibrationFilePath);
    obj.CalibrationTables.SoundCal = SoundCal;
catch
    obj.CalibrationTables.SoundCal = [];
end

% Load input channel settings
if ~exist(obj.Path.InputConfig)
    copyfile(fullfile(obj.Path.BpodRoot, 'Examples', 'Example Settings Files', 'InputConfig.mat'), obj.Path.InputConfig);
end
load(obj.Path.InputConfig);
obj.InputsEnabled = BpodInputConfig;

% Load sync settings
if ~exist(obj.Path.SyncConfig)
    copyfile(fullfile(obj.Path.BpodRoot, 'Examples',...
        'Example Settings Files', 'SyncConfig.mat'), obj.Path.SyncConfig);
end
load(obj.Path.SyncConfig);
obj.SyncConfig = BpodSyncConfig;

% Create module USB port config file (if not present)
if ~exist(obj.Path.ModuleUSBConfig)
    copyfile(fullfile(obj.Path.BpodRoot, 'Examples',...
        'Example Settings Files', 'ModuleUSBConfig.mat'), obj.Path.ModuleUSBConfig);
end
end