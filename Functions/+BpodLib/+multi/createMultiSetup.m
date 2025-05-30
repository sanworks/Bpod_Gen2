function createMultiSetup(BpodSystem)
% createMultiSetup(BpodSystem)
%   This function creates a new multi setup for the Bpod system.
%   It creates

isMulti = BpodLib.multi.isMultiSetup(BpodSystem);  % Check if the system is already in multi mode

% -- Intialising new setup
if ~isMulti
    % Create the new setup
    movefile(BpodLib.path.getPath(BpodSystem, 'settings', 'setuptype', 'single'), ...
        BpodLib.path.getPath(BpodSystem, 'settings', 'setuptype', 'multi'))
    return
end

% -- A new setup is being created alongside existing multi setup
settingsPath = BpodLib.path.getPath(BpodSystem, 'settings', 'setuptype', 'multi');
if isfolder(settingsPath)
    error('BpodLib:LiquidCalibration:MultiSetupAlreadyCreated', 'The multi-setup for the liquid calibration for this COM already exists.')
end

% Settings Files

% Calibration Files
calibrationFolderpath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration', 'setuptype', 'multi');
mkdir(calibrationFolderpath)
copyfile(fullfile(BpodLib.path.getPath(BpodSystem, 'root'), 'Examples/Example Calibration Files/'), calibrationFolderpath)

end