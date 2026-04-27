function completed = convertSettingsFolder(BpodSystem, varargin)
% Convert Calibration Files/ and Settings/ into Config/
% completed = convertSettingsFolder(BpodSystem, _)
%
% Arguments
% ----------
% BpodSystem : BpodObject
%
% Keyword Arguments
% -----------------
% verbose : logical (default=true)
%     Whether to display progress messages
%
% Returns
% -------
% completed : int
%     Returns 1 if conversion was successful, 0 otherwise

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

p = inputParser();
p.addParameter('verbose', true)
p.parse(varargin{:})

completed = 0;

if verLessThan('matlab', '9.1')
    warning('Your MATLAB version (%s) is older than R2016b (9.1). New liquid calibration format requires jsonencode/jsondecode from R2016b.', version);
    
    % Optionally provide more details or suggestions
    fprintf('  Consider upgrading to MATLAB R2016b or newer for full functionality.\n');
    return
end

% Set file paths
calibrationFolderpath = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files');
settingsFolderpath = fullfile(BpodSystem.Path.LocalDir, 'Settings');
oldFilepath = fullfile(calibrationFolderpath, 'LiquidCalibration.mat');
newFilepath = fullfile(calibrationFolderpath, 'LiquidCalibration.json'); % the intermediate location of the new liquid calibration file

configFolderpath = BpodLib.path.getPath('config', BpodSystem, 'setuptype', 'single');

% Check if the conversion script has to be run
previouslyCompleted = false;

% Check if any form of .json exists in the calibration file folder
if isfile(newFilepath)
    previouslyCompleted = true;
end
if ~isfile(oldFilepath)
    previouslyCompleted = true;
end
if isfolder(configFolderpath)
    previouslyCompleted = true;
end

if previouslyCompleted
    warning('Conversion script is detected as already having been run, run cancelled.')
    return
end

BpodLib.BpodObject.setup.compatibility.saveSettingsBackup(BpodSystem.Path.LocalDir, 'verbose', p.Results.verbose);

%% Convert liquid calibration file
% Save the new format
try
    BpodLib.calibration.liquid.compatibility.convertMAT2JSON(BpodSystem, oldFilepath, newFilepath);
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

if BpodLib.multi.isMultiSetup(BpodSystem)
    error('BpodLib:convertSettingsFolder:MultiSetup', 'Legacy liquid calibration detected but multi-setup detected. This is not supported, liquid calibration has to be converted to the new format first.');
end

% Move all files from Calibration Files to Settings
files = dir(fullfile(calibrationFolderpath, '*.*'));
for idx = 1:numel(files)
    if files(idx).isdir
        continue
    end
    if strcmp(files(idx).name, 'OLD LiquidCalibration.mat')
        continue
    end
    sourceFile = fullfile(calibrationFolderpath, files(idx).name);
    destFile = fullfile(settingsFolderpath, files(idx).name);
    movefile(sourceFile, destFile);
end

% Move Settings/ to Config/
movefile(settingsFolderpath, configFolderpath);

% Leave files pointing to new file locations
mkdir(settingsFolderpath);  % Recreate the Settings folder
createInfoFile(fullfile(settingsFolderpath, 'files moved to Config folder.txt'), BpodSystem.Path.LocalDir)
createInfoFile(fullfile(calibrationFolderpath, 'files moved to Config folder.txt'), BpodSystem.Path.LocalDir)

% Attach the new file into LiquidCal
BpodSystem.CalibrationTables.LiquidCal = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'type', 'statemachine');

BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', BpodSystem.Path.LocalDir);
completed = 1;

end

function createInfoFile(filepath, newLocalDir)
fid = fopen(filepath, 'w');
if fid == -1
    error('Could not create info file at: %s', filepath);
end
fprintf(fid, 'This folder has had its contents moved to %s/Config/ folder.\nThis conversion was performed: %s\nThis folder can be deleted.', newLocalDir, BpodLib.utils.isotime());
fclose(fid);
end