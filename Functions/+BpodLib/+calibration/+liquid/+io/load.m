function liquidData = load(varargin)
% Load a calibration file into BpodSystem
% :return liquidData: The liquid data determined to be for the state machine
% :rtype: struct or BpodLib.calibration.liquid.ValveDataManagerClass

% todo: create tests for this
p = inputParser();
p.addParameter('BpodSystem', [])  % todo: rethink the usage of BpodSystem here
p.parse(varargin{:})
BpodSystem = p.Results.BpodSystem;

calibrationFolderpath = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files');

filelist = dir(calibrationFolderpath);  % todo: maybe use a struct of files to do the logical work?
isLegacy = any(strcmp({filelist.name}, 'LiquidCalibration.mat'));
isJSON = any(strcmp({filelist.name}, 'LiquidCalibration.json'));
isMulti = BpodLib.utils.isMultiSetup(BpodSystem);


% Non-multi setup cases
if isJSON
    liquidData = BpodLib.calibration.liquid.ValveDataManagerClass('filepath', fullfile(calibrationFolderpath, 'LiquidCalibration.json'));
    if isLegacy
        warning('Returning LiquidCalibration.json but LiquidCalibration.mat exists, LiquidCalibration.mat should not exist in Calibration Files/')
    end
    if isMulti
        warning('Bpod detected this is a computer that may have multiple state machines plugged in but found a single-setup liquid calibration file.')
    end
    return
else
    if isLegacy
        liquidData = load(fullfile(calibrationFolderpath, 'LiquidCalibration.mat'), 'LiquidCal').LiquidCal;
        return
    end
end

if ~isMulti
    % No valid data found
    liquidData = [];
end

% Multi-setup support
eligibleFiles = BpodLib.calibration.liquid.multi.findCalibrationFiles(BpodSystem);
currentCOM = BpodLib.utils.getCurrentCOM(BpodSystem);
expectedFilename = sprintf('LiquidCalibration-%s.json', currentCOM);
if ~ismember(expectedFilename, eligibleFiles)
    % todo: create diagnostic showing possible actions
    error('Eligible liquid calibration file not found.')
end

liquidData = BpodLib.calibration.liquid.ValveDataManagerClass('filepath', fullfile(calibrationFolderpath, expectedFilename));


end