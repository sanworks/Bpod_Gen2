function liquidData = load(varargin)
% Load a calibration file into BpodSystem
% :return liquidData: The liquid data determined to be for the state machine
% :rtype: struct or BpodLib.calibration.liquid.ValveDataManagerClass

% todo: create tests for this
p = inputParser();
p.addParameter('BpodSystem', [])
p.addParameter('type', 'statemachine')
p.addParameter('index', [])
p.parse(varargin{:})
BpodSystem = p.Results.BpodSystem;

% todo: handle multi more gracefully
switch lower(p.Results.type)
    case 'statemachine'
        filename = 'LiquidCalibration.json';
    case 'portarray'
        filename = sprintf('LiquidCalibration-PA%i.json', p.addParameter.index);
    otherwise
        error('BpodLib:LiquidCalibration:UnrecognisedType', "Load type '%s' not recognised, should be 'statemachine' or 'portarray'", p.Results.type)
end

isMulti = BpodLib.multi.isMultiSetup(BpodSystem);
if isMulti
    calibrationFolderpath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration');
else
    calibrationFolderpath = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files');
end


filelist = dir(calibrationFolderpath);
isLegacy = any(strcmp({filelist.name}, 'LiquidCalibration.mat'));
isJSON = any(strcmp({filelist.name}, 'LiquidCalibration.json'));

expectedFilepath = fullfile(calibrationFolderpath, filename);

% Non-multi setup cases
if isJSON
    liquidData = BpodLib.calibration.liquid.ValveDataManagerClass('filepath', expectedFilepath);
    if isLegacy
        warning('Returning LiquidCalibration.json but LiquidCalibration.mat exists, LiquidCalibration.mat should not exist in Calibration Files/')
    end
    if isMulti
        warning('Bpod detected this is a computer that may have multiple state machines plugged in but found a single-setup liquid calibration file.')
    end
    return
else
    if isLegacy
        assert(strcmp(p.Results.type, 'portarray'), 'BpodLib') % todo: complete error msg
        liquidData = load(fullfile(calibrationFolderpath, 'LiquidCalibration.mat'), 'LiquidCal').LiquidCal;
        % Eventually this should return a warning for being unsupported
        return
    end
end


% Multi-setup support
liquidData = BpodLib.calibration.liquid.ValveDataManagerClass('filepath', expectedFilename);

end