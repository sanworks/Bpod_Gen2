function createMultiSetup(BpodSystem, varargin)
% Create a multi-setup compatible liquid calibration file


p = inputParser();
p.parse(varargin{:})

if ~BpodLib.multi.isMultiSetup(BpodSystem)
    ValveManager = BpodSystem.CalibrationTables.LiquidCal;
    assert(~isa(ValveManager, 'struct'), 'LiquidCal should be a ValveDataManagerClass object.')

    calibrationFolderpath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration', 'setuptype', 'single');

    newFolderpath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration', 'setuptype', 'multi');

    if isfolder(newFolderpath)
        error('BpodLib:LiquidCalibration:MultiSetupAlreadyCreated', 'The multi-setup for the liquid calibration for this COM already exists.')
    end

    % Create the COM specific liquid calibration folder
    mkdir(newFolderpath)

    % Rename file based on numbering
    moveableFilenames = {'LiquidCalibration.json', 'LiquidCalibration-PortArrays.json'};
    for idx = 1:numel(moveableFilenames)
        moveableFilepath = fullfile(calibrationFolderpath, moveableFilenames{idx});
        if isfile(moveableFilepath)
            movefile(moveableFilepath, fullfile(newFolderpath, moveableFilenames{idx}))
        end
    end
    return
end

% -- If there's already a multi setup, we need to initialise a "fresh" one
newFolderpath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration', 'setuptype', 'multi');
if isfolder(newFolderpath)
    error('BpodLib:LiquidCalibration:MultiSetupAlreadyCreated', 'The multi-setup for the liquid calibration for this COM already exists.')
end

mkdir(newFolderpath)
copyfile(fullfile(BpodLib.path.getPath(BpodSystem, 'root'), 'Examples/Example Calibration Files/'), newFolderpath)

end