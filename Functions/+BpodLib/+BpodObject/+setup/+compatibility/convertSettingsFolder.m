function Completed = convertSettingsFolder(BpodSystem, varargin)
% Completed = convertSettingsFolder(BpodSystem)
% Convert a Bpod Local folder with Calibration Files/ and Settings/ into only Config/


p = inputParser();
p.addParameter('verbose', true)
p.parse(varargin{:})

Completed = 0;

if verLessThan('matlab', '9.1')
    warning('Your MATLAB version (%s) is older than R2016b (9.1). New liquid calibration format requires jsonencode/jsondecode from R2016b.', version);
    
    % Optionally provide more details or suggestions
    fprintf('  Consider upgrading to MATLAB R2016b or newer for full functionality.\n');
    return
end

calibrationFolderpath = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files');
oldFilepath = fullfile(calibrationFolderpath, 'LiquidCalibration.mat');
newFilepath = fullfile(calibrationFolderpath, 'LiquidCalibration.json');

% Check if the conversion script has to be run
previouslyCompleted = false;

% Check if any form of .json exists in the calibration file folder
if isfile(newFilepath)
    previouslyCompleted = true;
end
if ~isfile(oldFilepath)
    previouslyCompleted = true;
end

if previouslyCompleted
    warning('Conversion script is detected as already having been run, run cancelled.')
    return
end

BpodLib.BpodObject.setup.compatibility.saveSettingsBackup(BpodSystem.Path.LocalDir, 'verbose', p.Results.verbose);

% Save the new format
try
    BpodLib.calibration.liquid.compatibility.convertMAT2JSON(BpodSystem, oldFilepath, newFilepath);
    Completed = 1;
catch ME
    disp('Conversion of liquid calibration failed.')
    rethrow(ME)
end

% Rename the old file
modifiedFilepath = fullfile(calibrationFolderpath, 'OLD LiquidCalibration.mat');

movefile(oldFilepath, modifiedFilepath);
if p.Results.verbose
    disp('Successfully converted LiquidCalibration.mat to LiquidCalibration.json');
end


%% Move files from Calibration Files to Settings
if ~isfile(fullfile(BpodSystem.Path.LocalDir, 'Calibration Files/LiquidCalibration.json'))
    return
end

if BpodLib.multi.isMultiSetup(BpodSystem)
    error('BpodLib:convertSettingsFolder:MultiSetup', 'Legacy liquid calibration detected but multi-setup detected. This is not supported, liquid calibration has to be converted to the new format first.');
end

% Move contents of Calibration Files/ to Settings/
calibrationFolder = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files');
settingsFolder = fullfile(BpodSystem.Path.LocalDir, 'Settings');

% Move all files from Calibration Files to Settings
files = dir(fullfile(calibrationFolder, '*.*'));
for idx = 1:numel(files)
    if files(idx).isdir
        continue
    end
    if strcmp(files(idx).name, 'OLD LiquidCalibration.mat')
        continue
    end
    sourceFile = fullfile(calibrationFolder, files(idx).name);
    destFile = fullfile(settingsFolder, files(idx).name);
    movefile(sourceFile, destFile);
end

% rename Settings to Config
movefile(settingsFolder, fullfile(BpodSystem.Path.LocalDir, 'Config'));
mkdir(settingsFolder);  % Recreate the Settings folder
fid = fopen(fullfile(settingsFolder, 'files moved to Config folder.txt'), 'w');
fprintf(fid, 'This folder has had its contents moved to the Bpod Local/Config/ folder.\nThis conversion was performed: %s\nThis folder can be deleted.', BpodLib.utils.isotime());
fclose(fid);

% Attach the new file into LiquidCal
BpodSystem.CalibrationTables.LiquidCal = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'type', 'statemachine');

% Place a note in the Calibration Files folder
fid = fopen(fullfile(calibrationFolder, 'calibration files have moved.txt'), 'w');
fprintf(fid, 'This folder has had its contents moved Bpod Local/Config/ folder.\nThis conversion was performed: %s\nThis folder can be deleted.', BpodLib.utils.isotime());
fclose(fid);
Completed = 1;

BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', BpodSystem.Path.LocalDir);

end