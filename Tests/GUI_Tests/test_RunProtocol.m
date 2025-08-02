function tests = test_RunProtocol()
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    BpodTest.setupBpodSystemFixture(testCase)
end

function teardownOnce(testCase)
    BpodTest.teardownBpodSystemFixture(testCase)
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
    rmdir(testCase.TestData.root, 's');
end

function test_runLaunchManager(testCase)
    % Test that the UI can run a protocol
    % Ensure that the empty protocol is there



    %
    BpodSystem = testCase.TestData.Original.BpodSystem;
    BpodTest.ui.click(BpodSystem.GUIHandles.RunButton)

    BpodSystem.GUIHandles.ProtocolSelector.Value = 1;
    protocolName = BpodSystem.GUIHandles.ProtocolSelector.String{BpodSystem.GUIHandles.ProtocolSelector.Value};
    testCase.verifyTrue(strcmp(protocolName, 'CoreTestProtocol'), ...
        'Should selector correct protocol.')

    BpodSystem.GUIHandles.SubjectSelector.Value = 1;
    subjectName = BpodSystem.GUIHandles.SubjectSelector.String{BpodSystem.GUIHandles.SubjectSelector.Value};
    testCase.verifyTrue(strcmp(subjectName, 'FakeSubject'), ...
        'Should select correct subject.')

    BpodSystem.GUIHandles.SettingsSelector.Value = 1;
    settingsName = BpodSystem.GUIHandles.SettingsSelector.String{BpodSystem.GUIHandles.SettingsSelector.Value};
    testCase.verifyTrue(strcmp(settingsName, 'DefaultSettings'),...
        'Should select correct settings.')

    BpodTest.ui.click(BpodSystem.GUIHandles.LaunchButton)
    pause(0.5)
    BpodTest.ui.click(BpodSystem.GUIHandles.EndButton)
end

% function test_runWithMachine(testCase)
%     BpodSystem = testCase.TestData.MachineBpod;
% end