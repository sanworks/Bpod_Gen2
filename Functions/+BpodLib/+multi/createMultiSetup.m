function createMultiSetup(BpodSystem)
% createMultiSetup(BpodSystem)
%   This function creates a new multi setup for the Bpod system.
%   It creates

isMulti = BpodLib.multi.isMultiSetup(BpodSystem);  % Check if the system is already in multi mode

% -- Intialising new setup
if ~isMulti
    % Create the new setup
    movefile(BpodLib.path.getPath('settings', BpodSystem, 'setuptype', 'single'), ...
        BpodLib.path.getPath('settings', BpodSystem, 'setuptype', 'multi'))
    return
end

% -- A new setup is being created alongside existing multi setup
settingsPath = BpodLib.path.getPath('settings', BpodSystem, 'setuptype', 'multi');
if isfolder(settingsPath)
    error('BpodLib:LiquidCalibration:MultiSetupAlreadyCreated', 'The multi-setup for the liquid calibration for this COM already exists.')
end

% Settings Files

% Calibration Files
calibrationFolderpath = BpodLib.path.getPath('liquidcalibration', BpodSystem, 'setuptype', 'multi');
mkdir(calibrationFolderpath)
copyfile(fullfile(BpodLib.path.getPath('root', BpodSystem), 'Examples/Example Calibration Files/'), calibrationFolderpath)

end