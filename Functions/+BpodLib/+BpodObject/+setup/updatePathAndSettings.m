function updatePathAndSettings(BpodSystem, varargin)
% Update Bpod system paths and settings configuration.
% updatePathAndSettings(BpodSystem, _)
%
% Sets up paths to folders and prepares folder structure. This function is called:
% - At Bpod startup
% - When file structure is changed during multi-setup initialization
%
% Modifies BpodSystem's Path property
%
% Parameters
% ----------
% BpodSystem : struct
%     The Bpod system object
%
% Keyword Arguments
% -----------------
% LocalDir : char (default='')
%     Path to Bpod Local directory. If empty, uses default location.
% verbose : logical (default=false)
%     Whether to display progress messages.

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

p = inputParser;
p.addParameter('LocalDir', '');
p.addParameter('verbose', false, @islogical);
p.parse(varargin{:});

existingPath = BpodSystem.Path;

%% -- Setup core pathing
Path = struct();
Path.BpodRoot = BpodLib.path.getPath('root');
Path.ParentDir = fileparts(Path.BpodRoot);

if isempty(p.Results.LocalDir)
    Path.LocalDir = fullfile(Path.ParentDir, 'Bpod Local');
else
    Path.LocalDir = p.Results.LocalDir;
end
LocalDir = Path.LocalDir;

% SettingsDir will be Config/ unless setup uses legacy folder structure
Path.SettingsDir = BpodLib.path.getPath('settings', BpodSystem, 'LocalDir', LocalDir);

if ~isfolder(Path.LocalDir)
    mkdir(Path.LocalDir);
end
if ~isfolder(Path.SettingsDir)
    mkdir(Path.SettingsDir);
end

%% -- Configure user-settable BpodSettings paths
ExamplesDir = fullfile(Path.BpodRoot, 'Examples');

% Load system settings if they exist
if isfile(fullfile(Path.SettingsDir, 'BpodSettings.mat'))
    BpodSystem.SystemSettings = load(fullfile(Path.SettingsDir, 'BpodSettings.mat'), 'BpodSettings').BpodSettings;
else
    BpodSystem.SystemSettings = struct();
end

% Process user folders from settings
userFolders = {'ProtocolFolder', 'DataFolder', 'BcontrolRootFolder'};
for idx = 1:numel(userFolders)
    folderType = userFolders{idx};
    Path.(folderType) = '';
    if isfield(BpodSystem.SystemSettings, folderType)
        if isfolder(BpodSystem.SystemSettings.(folderType))
            Path.(folderType) = BpodSystem.SystemSettings.(folderType);
        end
    end
end

% Add ExpertPort to path if Bcontrol exists
% todo: this is untested
if isfolder(Path.BcontrolRootFolder)
    ExperPortFolder = fullfile(Path.BcontrolRootFolder, 'ExperPort');
    if isfolder(ExperPortFolder)
        addpath(ExperPortFolder)
    end
end

%% -- Calibration Files
calFolder = BpodLib.path.getPath('liquidcalibration', BpodSystem, 'LocalDir', LocalDir);

if ~isfile(fullfile(Path.SettingsDir, 'LiquidCalibration.json')) && ~BpodLib.path.compatibility.isLegacySettings(Path.LocalDir)
    fileNames = {'LiquidCalibration.json', 'SoundCalibration.mat', 'Readme.txt'};
    for idx = 1:numel(fileNames)
        fileName = fileNames{idx};
        copyfile(fullfile(ExamplesDir, 'Example Calibration Files', fileName), fullfile(calFolder, fileName));
    end
    if p.Results.verbose
        msg = msgbox(["Detected new setup and created files at:"; Path.SettingsDir; "Replace example calibration files soon."], 'Settings folder not found', 'help', 'modal');
        uiwait(msg)
    end
end

try
    BpodSystem.CalibrationTables.LiquidCal = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'LocalDir', LocalDir, 'type', 'statemachine');
    if strcmp(BpodLib.calibration.liquid.utils.checkCOM(BpodSystem), 'no')
        if p.Results.verbose
            warning('BpodLib:Calibration:Liquid:CheckCOM', 'Calibration file does not match the detected state machine''s USB serial port.');
            msg = msgbox(sprintf("Detected state machine USB serial port (%s) does not match the port used to create the current liquid calibration: (%s).\nPlease either initialize a multi-machine setup or re-run calibration.", ...
                BpodLib.utils.getCurrentCOM(BpodSystem), BpodSystem.CalibrationTables.LiquidCal.metadata.COM), ...
                'Calibration USB Port mismatch', 'warn', 'modal');
            uiwait(msg)
        end
    end
catch err
    if strcmp(err.identifier, 'BpodLib:LiquidCalibrationLoad:FileNotFound')
        BpodSystem.CalibrationTables.LiquidCal = [];
    else
        rethrow(err)
    end
end


try
    BpodSystem.CalibrationTables.PortArrays = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'LocalDir', LocalDir, 'type', 'portarray');
catch err
    if strcmp(err.identifier, 'BpodLib:LiquidCalibrationLoad:FileNotFound')
        BpodSystem.CalibrationTables.PortArrays = [];
    elseif strcmp(err.identifier, 'BpodLib:LiquidCalibration:PortArrayJSONFail')
        BpodSystem.CalibrationTables.PortArrays = [];
    else
        rethrow(err)
    end
end

% Load sound calibration
try
    soundCalibrationFilePath = fullfile(calFolder, 'SoundCalibration.mat');
    load(soundCalibrationFilePath);
    BpodSystem.CalibrationTables.SoundCal = SoundCal;
catch
    BpodSystem.CalibrationTables.SoundCal = [];
end

%% -- Config files
configItems = {'InputConfig', 'SyncConfig', 'ModuleUSBConfig'};
for idx = 1:numel(configItems)
    configItem = configItems{idx};
    fileName = [configItem '.mat'];
    configFilepath = fullfile(Path.SettingsDir, fileName);
    Path.(configItem) = configFilepath;

    if ~isfile(Path.(configItem))
        if ~strcmp(configItem, 'InputConfig')
            copyfile(fullfile(ExamplesDir, 'Example Settings Files', fileName), Path.(configItem));
        end
    end

    if strcmp(configItem, {'ModuleUSBConfig'})
        continue
    elseif strcmp(configItem, 'InputConfig')
        if ~isfile(Path.(configItem))
            % Only load if a user defined
            continue
        end
        loaded_item = load(Path.(configItem), 'BpodInputConfig');
        BpodSystem.InputsEnabled = loaded_item.BpodInputConfig;
    elseif strcmp(configItem, 'SyncConfig')
        loadedItem = load(Path.(configItem), 'BpodSyncConfig');
        BpodSystem.SyncConfig = loadedItem.BpodSyncConfig;
    else
        error('Unknown config item: %s', configItem);
    end
end

Path.FlexConfig = fullfile(Path.SettingsDir, 'FlexConfig.mat');

%% -- Add dynamic paths to Path
% These are set when a protocol is run, so copy them from existingPath if available.
if ~isempty(existingPath)
    % Copy standard dynamic paths
    dynamicNames = {'Settings', 'CurrentDataFile', 'CurrentProtocol'};
    for idx = 1:numel(dynamicNames)
        dynamicName = dynamicNames{idx};
        if isfield(existingPath, dynamicName)
            Path.(dynamicName) = existingPath.(dynamicName);
        else
            Path.(dynamicName) = '';
        end
    end
    
    % Add any additional paths from existingPath
    dynamicNames = fieldnames(existingPath);
    for idx = 1:numel(dynamicNames)
        dynamicName = dynamicNames{idx};
        if ~isfield(Path, dynamicName)
            Path.(dynamicName) = existingPath.(dynamicName);
        end
    end

    pathNames = fieldnames(Path);
    for idx = 1:numel(pathNames)
        pathName = pathNames{idx};
        if isfield(existingPath, pathName) && ~strcmp(Path.(pathName), existingPath.(pathName))
            if p.Results.verbose
                fprintf('Path %s changed from %s to %s\n', pathName, existingPath.(pathName), Path.(pathName));
            end
        end
    end
end

%% -- Add paths to BpodSystem
BpodSystem.Path = Path;

if ~strcmp(BpodSystem.Path.SettingsDir, BpodLib.path.getPath('Settings', BpodSystem, 'LocalDir', LocalDir))
    warning('BpodLib:PathSetup:SettingsMatchFail','SettingsDir setup does not match BpodLib path. This will cause issues with loading settings.');
    % I don't see why this would happen, but if it does it's going to be a problem.
end

end