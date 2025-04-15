function createMultiSetup(BpodSystem, varargin)
% Create a multi-setup compatible liquid calibration file


p = inputParser();
% p.addParameter('BpodSystem', [])
p.parse(varargin{:})


ValveManager = BpodSystem.CalibrationTables.LiquidCal;
assert(~isa(ValveManager, 'struct'), 'LiquidCal should be a ValveDataManagerClass object.')

calibrationFolderpath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration', 'setuptype', 'single');
currentFilepath = fullfile(calibrationFolderpath, 'LiquidCalibration.json');

newFolderpath = fullfile(BpodLib.path.getPath(BpodSystem, 'liquidcalibration', 'setuptype', 'multi'));
newFilepath = fullfile(newFolderpath, 'LiquidCalibration.json');
% todo: move PortArray files

if isfolder(newFolderpath)
    error('BpodLib:LiquidCalibration:MultiSetupAlreadyCreated', 'The multi-setup for the liquid calibration for this COM already exists.')
end

% Create the COM specific liquid calibration folder
mkdir(newFolderpath)

% Rename file based on numbering
movefile(currentFilepath, newFilepath)

end