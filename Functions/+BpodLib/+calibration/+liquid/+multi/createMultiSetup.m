function createMultiSetup(BpodSystem, varargin)

p = inputParser();
% p.addParameter('BpodSystem', [])
p.parse(varargin{:})


ValveManager = BpodSystem.CalibrationTables.LiquidCal;
assert(~isa(ValveManager, 'struct'), 'LiquidCal should be a ValveDataManagerClass object.')

calibrationFolderpath = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files');
currentFilepath = fullfile(calibrationFolderpath, 'LiquidCalibration.json');
multiFilenames = BpodLib.calibration.liquid.multi.findCalibrationFiles(BpodSystem);
if numel(multiFilenames) > 1
    error('Requested to make a multi-setup liquid calibration file but this script has already run. Manual creation recommended.')
    % todo: insert into docs?
end

% Insert COM into filename
comport = BpodLib.utils.getCurrentCOM(BpodSystem);
newname = sprintf('LiquidCalibration-%s.json',comport);
newFilepath = fullfile(calibrationFolderpath, newname);

% Rename file based on numbering
movefile(currentFilepath, newFilepath)

end