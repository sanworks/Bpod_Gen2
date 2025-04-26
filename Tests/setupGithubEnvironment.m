%% Prepare GitHub environment
% Create Bpod_Local folder
parentDir = fileparts(pwd);
localDir = fullfile(parentDir, 'Bpod Local');
calFolder = fullfile(localDir, 'Calibration Files');
mkdir(localDir)
mkdir(calFolder)
copyfile(fullfile(parentDir, 'Bpod_Gen2/Examples/Example Calibration Files'), calFolder)

% Startup bpod
Bpod EMU
EndBpod
%% Run all of the tests
% the workflow will run the tests