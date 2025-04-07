function Completed = conversionscript(BpodSystem)
% Convert the Liquid Calibration .mat file to the new .json format

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
    return
end

% Save the new format
try
    BpodLib.calibration.liquid.compatibility.convertMAT2JSON(oldFilepath, newFilepath);
    Completed = 1;
catch ME
    disp('Conversion of liquid calibration failed.')
    rethrow(ME)
end

% Rename the old file
modifiedFilepath = fullfile(calibrationFolderpath, 'OLD LiquidCalibration.mat');

movefile(oldFilepath, modifiedFilepath);
disp('Successfully converted LiquidCalibration.mat to LiquidCalibration.json');
% msg = ["Bpod Local/Calibration Files/LiquidCalibration.mat has been converted to the new format: LiquidCalibration.json"; ...
% "No change to existing installations/setups should occur."];
% msgbox(msg, 'Success', 'modal')