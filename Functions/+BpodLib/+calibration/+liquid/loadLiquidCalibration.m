function liquidData = loadLiquidCalibration(varargin)
% Load a calibration file into BpodSystem

p = inputParser();
p.addParameter('BpodSystem', [])
p.parse(varargin{:})

BpodSystem = BpodLib.utils.getBpodSystem(p);

calibrationFolderpath = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files');
legacyLiquidCalibrationFilePath = fullfile(calibrationFolderpath, 'LiquidCalibration.mat');
liquidCalbrationFilepath = fullfile(calibrationFolderpath, 'LiquidCalibration.json');

if isfile(liquidCalbrationFilepath)
    liquidData = BpodLib.calibration.liquid.ValveDataManagerClass('filepath', liquidCalbrationFilepath);
    if isfile(legacyLiquidCalibrationFilePath)
        warning('Returning LiquidCalibration.json but LiquidCalibration.mat exists, LiquidCalibration.mat should not exist.')
    end
    return
end

if ~isfile(legacyLiquidCalibrationFilePath)
    liquidData = [];
    % This should basically not occur
    return
end

liquidData = load(legacyLiquidCalibrationFilePath, 'LiquidCal').LiquidCal;

end