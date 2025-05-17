function liquidData = load(varargin)
% Load a calibration file from disk
%
% :param type: Source to read for the file either 'statemachine' (default) or 'portarray'
% :type type: char
% :return liquidData: The liquid data determined to be for the state machine
% :rtype: struct or BpodLib.calibration.liquid.ValveDataManagerClass

p = inputParser();
p.addParameter('BpodSystem', [])
p.addParameter('type', [])
p.parse(varargin{:})
BpodSystem = p.Results.BpodSystem;

switch lower(p.Results.type)
    case 'statemachine'
        filename = 'LiquidCalibration.json';
    case 'portarray'
        filename = 'LiquidCalibration-PortArrays.json';
    otherwise
        error('BpodLib:LiquidCalibration:UnrecognisedType', "Load type '%s' not recognised, should be 'statemachine' or 'portarray'", p.Results.type)
end

calibrationFolderpath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration');
expectedFilepath = fullfile(calibrationFolderpath, filename);

% Verify that file structure is as expected
isLegacy = isfile(fullfile(calibrationFolderpath, 'LiquidCalibration.mat'));
isJSON = isfile(fullfile(calibrationFolderpath, 'LiquidCalibration.json'));
isMulti = BpodLib.multi.isMultiSetup(BpodSystem);
if isJSON
    if isLegacy
        warning('BpodLib:LiquidCalibrationLoad:LegacyAndJSON', 'Returning LiquidCalibration.json but LiquidCalibration.mat exists, LiquidCalibration.mat should not exist in folder Calibration Files/')
    end
    singleSetupPath = fullfile(BpodLib.path.getPath(BpodSystem, 'liquidcalibration', 'setup', 'single'), 'LiquidCalibration.json');
    if isMulti && isfile(singleSetupPath)
        warning('BpodLib:LiquidCalibrationLoad:MultiAndSingle', 'Bpod detected this is a computer that may have multiple state machines plugged in but found a single-setup liquid calibration file.')
    end
else
    assert(isLegacy, 'Expected legacy .mat file because no .json file was found')
    assert(strcmp(p.Results.type, 'statemachine'), 'Port Array not supported with old .mat format.')
    liquidData = load(fullfile(calibrationFolderpath, 'LiquidCalibration.mat'), 'LiquidCal').LiquidCal;
    % Eventually this should return a warning for being unsupported
    return
end

liquidData = BpodLib.calibration.liquid.ValveDataManagerClass('filepath', expectedFilepath);

end