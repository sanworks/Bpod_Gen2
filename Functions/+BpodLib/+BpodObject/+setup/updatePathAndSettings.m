function updatePathAndSettings(BpodSystem, varargin)
% updatePathAndSettings(BpodSystem)
% Set up paths to folders and prepare folders.
% This is ran at Bpod startup and when file structure is changed during multi-setup initialization.

p = inputParser;
p.addParameter('LocalDir', '');
p.addParameter('verbose', false, @islogical);
p.parse(varargin{:});

% todo: make this whole thing use the COM format

existingPath = BpodSystem.Path;

%% -- Setup core pathing
Path = struct();
Path.BpodRoot = fileparts(which('Bpod'));
Path.ParentDir = fileparts(Path.BpodRoot);
if isempty(p.Results.LocalDir)
    Path.LocalDir = fullfile(Path.ParentDir, 'Bpod Local');
else
    Path.LocalDir = p.Results.LocalDir;
end

% Set settings path
if ~BpodLib.multi.isMultiSetup(BpodSystem, 'LocalDir', Path.LocalDir)
    Path.SettingsDir = fullfile(Path.LocalDir, 'Settings');
else
    Path.SettingsDir = fullfile(Path.LocalDir, 'Settings', sprintf('Machine-%s', BpodLib.utils.getCurrentCOM(BpodSystem)));
end

if ~isfolder(Path.LocalDir)
    mkdir(Path.LocalDir);
end
if ~isfolder(Path.SettingsDir)
    mkdir(Path.SettingsDir);
end

ExamplesDir = fullfile(Path.BpodRoot, 'Examples');
%% -- Configure user-settable BpodSettings paths
if isfile(fullfile(Path.SettingsDir, 'BpodSettings.mat'))
    BpodSystem.SystemSettings = load(fullfile(Path.SettingsDir, 'BpodSettings.mat'), 'BpodSettings').BpodSettings;
else
    BpodSystem.SystemSettings = struct();
end

% Specify user paths only if they are set in BpodSettings.mat and also exist
userFolders = {'ProtocolFolder', 'DataFolder', 'BcontrolRootFolder'};
for idx = 1:numel(userFolders)
    foldertypename = userFolders{idx};
    Path.(foldertypename) = '';
    if isfield(BpodSystem.SystemSettings, foldertypename)
        if isfolder(BpodSystem.SystemSettings.(foldertypename))
            Path.(foldertypename) = BpodSystem.SystemSettings.(foldertypename);
        end
    end
end

if isfolder(Path.BcontrolRootFolder)
    ExperPortFolder = fullfile(Path.BcontrolRootFolder, 'ExperPort');
    if isfolder(ExperPortFolder)
        addpath(ExperPortFolder)
    end
end

%% -- Calibration Files
calFolder = BpodLib.path.getPath(BpodSystem, 'liquidcalibration');
if ~isfolder(calFolder)
    mkdir(calFolder)
    copyfile(fullfile(ExamplesDir, 'Example Calibration Files/'), calFolder)
    if p.Results.verbose
        % todo: this message could work to inform users about new COM-detected
        questdlg('Calibration folder created in /BpodLocal/. Replace example calibration files soon.', ...
                        'Calibration folder not found', ...
                        'Ok', 'Ok');
    end
end

try
    BpodSystem.CalibrationTables.LiquidCal = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'type', 'statemachine');
catch err
    if strcmp(err.identifier, 'BpodLib:LiquidCalibrationLoad:FileNotFound')
        BpodSystem.CalibrationTables.LiquidCal = [];
    else
        rethrow(err)
    end
end


try
    BpodSystem.CalibrationTables.PortArrays = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'type', 'portarray');
catch err
    if strcmp(err.identifier, 'BpodLib:LiquidCalibrationLoad:FileNotFound')
        BpodSystem.CalibrationTables.PortArrays = [];
    else
        rethrow(err)
    end
end

% Load sound calibration
try
    soundCalibrationFilePath = fullfile(calFolder, 'SoundCalibration.mat');
    load(soundCalibrationFilePath);
    obj.CalibrationTables.SoundCal = SoundCal;
catch
    obj.CalibrationTables.SoundCal = [];
end

%% -- Config files
configItems = {'InputConfig', 'SyncConfig', 'ModuleUSBConfig'};
for idx = 1:numel(configItems)
    configItem = configItems{idx};
    fileName = [configItem '.mat'];
    configFilepath = fullfile(Path.SettingsDir, fileName);
    Path.(configItem) = configFilepath;
    if ~isfile(Path.(configItem))
        copyfile(fullfile(ExamplesDir, 'Example Settings Files', fileName), Path.(configItem));
    end

    if strcmp(configItem, {'ModuleUSBConfig'})
        continue
    elseif strcmp(configItem, 'InputConfig')
        loaded_item = load(Path.(configItem), 'BpodInputConfig');
        obj.InputsEnabled = loaded_item.BpodInputConfig;
    elseif strcmp(configItem, 'SyncConfig')
        loaded_item = load(Path.(configItem), 'BpodSyncConfig');
        obj.SyncConfig = loaded_item.BpodSyncConfig;
    else
        error('Unknown config item: %s', configItem);
    end
end

Path.FlexConfig = fullfile(Path.SettingsDir, 'FlexConfig.mat');

%% -- Add dynamics paths to Path
% These are set during protocol launch.
if ~isempty(existingPath)
    dynamicNames = {'Settings', 'CurrentDataFile', 'CurrentProtocol'};
    for idx = 1:numel(dynamicNames)
        dynamicName = dynamicNames{idx};
        if isfield(existingPath, dynamicName)
            Path.(dynamicName) = existingPath.(dynamicName);
        else
            Path.(dynamicName) = '';
        end
    end
    
    % Add paths in existingPath that aren't in Path
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

if ~strcmp(BpodSystem.Path.SettingsDir, BpodLib.path.getPath(BpodSystem, 'Settings'))
    warning('BpodLib:PathSetup:SettingsMatchFail','SettingsDir setup does not match BpodLib path. This will cause issues with loading settings.');
    % I don't see why this would happen, but if it does it's going to be a problem.
end

end