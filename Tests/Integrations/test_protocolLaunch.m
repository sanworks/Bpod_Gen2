function tests = test_protocolLaunch()
% Test launching a protocol without a GUI
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    BpodTest.setupBpodSystemFixture(testCase, 'gui', false);
end

function teardownOnce(testCase)
    BpodTest.teardownBpodSystemFixture(testCase);
end

function setup(testCase)
    % Setup local folder
    testCase.TestData.root = tempname;
    localDir = fullfile(testCase.TestData.root, 'Bpod Local');
    mkdir(localDir)
    testCase.TestData.LocalDir = localDir;
    protocolFolder = fullfile(localDir, 'Protocols');
    dataFolder = fullfile(localDir, 'Data');
    mkdir(protocolFolder)

    % Configure BpodSystem to use the test directory
    BpodSystem = testCase.TestData.BpodSystem;
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', localDir)
    BpodSystem.SystemSettings.ProtocolFolder = protocolFolder;
    BpodSystem.Path.DataFolder = dataFolder;
    
    % Put test protocols into the folder
    assetPath = BpodTest.getPath('assets');
    copyfile(fullfile(assetPath, 'CoreTestProtocol'), fullfile(protocolFolder, 'CoreTestProtocol'))
    copyfile(fullfile(assetPath, 'GUITestProtocol'), fullfile(protocolFolder, 'GUITestProtocol'))
    mkdir(fullfile(localDir, 'Data/FakeSubject/GUITestProtocol/Session Data'))
    mkdir(fullfile(localDir, 'Data/FakeSubject/CoreTestProtocol/Session Data'))
    mkdir(fullfile(localDir, 'Data/FakeSubject/CoreTestProtocol/Session Settings/'))
end

function teardown(testCase)
    rmdir(testCase.TestData.root, 's')
end

function test_headlessLaunch(testCase)
% Test that we can launch into a protocol without a GUI
BpodSystem = testCase.TestData.BpodSystem;
BpodLib.launcher.launchProtocol(BpodSystem, 'CoreTestProtocol', 'FakeSubject')
BpodLib.launcher.stopProtocol(BpodSystem)

% When protocol runs the data should update
testCase.verifyTrue(isfield(BpodSystem.Data, 'TrialOutcomes'), ...
    'BpodSystem.Data should have been created by the protocol launch');

% Verify that the data was saved into the expected location
dataFile = fullfile(BpodSystem.Path.DataFolder, 'FakeSubject/CoreTestProtocol/Session Data', ...
    'FakeSubject_CoreTestProtocol_*.mat');
files = dir(dataFile);
testCase.verifyTrue(~isempty(dir(dataFile)), ...
    'Data file should have been created in the expected location');
dataFilepath = fullfile(files(1).folder, files(1).name);
testCase.verifyTrue(isfile(dataFilepath), ...
    'Data file should exist at the expected path');

% Verify that the saved data contains the expected fields
SessionData = load(dataFilepath, 'SessionData').SessionData;
testCase.verifyTrue(isfield(SessionData, 'TrialOutcomes'),...
    'Data defined within protocol should be given.')

testCase.verifyTrue(isfield(SessionData.RawEvents.Trial{1}.States, 'Start'),...
    "The state 'Start' should have been entered into.")

end