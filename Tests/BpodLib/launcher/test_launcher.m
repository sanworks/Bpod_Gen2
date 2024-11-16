function tests = test_launcher
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Setup - Create a mock directory structure
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;

    testEnvironment = initializeTestEnvironment(rootPath);
    testCase.TestData.protocolFolder = testEnvironment.protocolFolder;
    testCase.TestData.dataFolder = testEnvironment.dataFolder;
end

function teardownOnce(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_prepareDataFolders(testCase)
    % Test the prepareDataFolders function
    subjectName = 'Subject1';
    protocolName = 'Protocol_unique_generated';
    subjectDataFolder = fullfile(testCase.TestData.dataFolder, subjectName);


    BpodLib.launcher.prepareDataFolders(subjectDataFolder, protocolName)

    % Test all of its parts
    testCase.verifyTrue(exist(fullfile(subjectDataFolder, protocolName), 'dir') == 7)
    testCase.verifyTrue(exist(fullfile(subjectDataFolder, protocolName, 'Session Data'), 'dir') == 7)
    testCase.verifyTrue(exist(fullfile(subjectDataFolder, protocolName, 'Session Settings'), 'dir') == 7)
    testCase.verifyTrue(exist(fullfile(subjectDataFolder, protocolName, 'Session Settings', 'DefaultSettings.mat'), 'file') == 2)
end

function test_findProtocols(testCase)
    % Test situation where they're the same
    BpodSystem = struct;
    BpodSystem.Path.ProtocolFolder = testCase.TestData.protocolFolder;
    BpodSystem.SystemSettings.ProtocolFolder = testCase.TestData.protocolFolder;

    protocolNames = BpodLib.launcher.findProtocols(BpodSystem);
    testCase.verifyEqual(protocolNames, {'<subfolderA>', '<subfolderB>', 'Protocol_matching1', 'Protocol_unique1', 'Protocol_unique2'})
end

function test_findProtocols_different(testCase)
    % Test situation where they're different
    BpodSystem = struct;
    BpodSystem.Path.ProtocolFolder = fullfile(testCase.TestData.protocolFolder, 'subfolderA');
    BpodSystem.SystemSettings.ProtocolFolder = testCase.TestData.protocolFolder;

    protocolNames = BpodLib.launcher.findProtocols(BpodSystem);
    testCase.verifyEqual(protocolNames, {'<..>', 'Protocol_matching1', 'Protocol_matching2'})
end

function test_findProtocols_different_nested(testCase)
    % Test situation where they're different, and further in
    BpodSystem = struct;
    BpodSystem.Path.ProtocolFolder = fullfile(testCase.TestData.protocolFolder, 'subfolderB/subfolderC');
    BpodSystem.SystemSettings.ProtocolFolder = testCase.TestData.protocolFolder;

    protocolNames = BpodLib.launcher.findProtocols(BpodSystem);
    testCase.verifyEqual(protocolNames, {'<..>', 'Protocol_unique4'})
end

function test_findSubjects(testCase)
    subjectNames = BpodLib.launcher.findSubjects(testCase.TestData.dataFolder, 'Protocol_matching1', 'FakeSubject');
    testCase.verifyEqual(subjectNames, {'FakeSubject', 'Subject1', 'Subject2'})
end

function test_findSubjects_nosubjects(testCase)
    % Even if protocol hasn't been run before it'll autopopulate with the dummy subject
    subjectNames = BpodLib.launcher.findSubjects(testCase.TestData.dataFolder, 'Protocol_nonexistent', 'FakeSubject');
    testCase.verifyEqual(subjectNames, {'FakeSubject'})
end

function test_findSettings(testCase)
    settingsFileNames = BpodLib.launcher.findSettings(testCase.TestData.dataFolder, 'Protocol_matching1', 'FakeSubject');
    testCase.verifyEqual(settingsFileNames, {'DefaultSettings', 'settings1'})
end