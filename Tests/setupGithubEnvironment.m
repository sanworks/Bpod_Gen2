%% Prepare GitHub environment
% Create Bpod_Local folder
parentDir = fileparts(pwd);
localDir = fullfile(parentDir, 'Bpod Local');
calFolder = fullfile(localDir, 'Calibration Files');
mkdir(localDir)
mkdir(calFolder)
copyfile(fullfile(parentDir, 'Bpod_Gen2/Examples/Example Calibration Files'), calFolder)

% GitHub Actions can't startup Bpod because of its GUI elements
% Have to add Bpod's paths manually
addpath(genpath(fullfile(parentDir, 'Bpod_Gen2/Functions')));
disp('Current MATLAB path:');
path

disp('Can find bpodlib?')
which('BpodLib.calibration.liquid.ValveDataClass')
% Bpod EMU
% EndBpod
%% Run all of the tests
% the workflow will run the tests