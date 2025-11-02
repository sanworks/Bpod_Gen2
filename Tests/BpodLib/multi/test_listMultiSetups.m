function tests = test_listMultiSetups()
    tests = functiontests(localfunctions);
end

function setup(testCase)
    % Setup test data that will be used for all tests
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    mkdir(testCase.TestData.rootPath)

    mockBpod = BpodLib.BpodObject.MockBpodObject('COM13');
    LocalDir = fullfile(rootPath, 'Bpod Local');
    mkdir(LocalDir)
    testCase.TestData.LocalDir = LocalDir;
    testCase.TestData.mockBpod = mockBpod;
    BpodLib.BpodObject.setup.updatePathAndSettings(mockBpod, 'LocalDir', LocalDir);

end

function teardown(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_listing(testCase)
    mockBpod = testCase.TestData.mockBpod;
    LocalDir = testCase.TestData.LocalDir;
    BpodLib.multi.createMultiSetup(mockBpod);

    % Build additional mock items
    comlist = {'COM5', 'COM14', 'COM15'};
    for idx = 1:numel(comlist)
        mockedBpod = BpodLib.BpodObject.MockBpodObject(comlist{idx});
        BpodLib.BpodObject.setup.updatePathAndSettings(mockedBpod, 'LocalDir', LocalDir);
    end
    % Test listing multi setups
    configDir = fullfile(testCase.TestData.LocalDir, 'Config');
    setups = BpodLib.multi.listMultiSetups(configDir);
    expectedSetups = strcat('Machine-', [{'COM13'}, comlist])';
    testCase.verifyEqual(sort(setups), sort(expectedSetups), 'The listed multi setups do not match the expected setups.');
end

function test_not_multi_setup(testCase)
    % Test listing multi setups when no multi setup exists
    mockBpod = testCase.TestData.mockBpod;
    LocalDir = testCase.TestData.LocalDir;

    configDir = BpodLib.path.getPath('config', mockBpod, 'LocalDir', LocalDir);
    setups = BpodLib.multi.listMultiSetups(configDir);
    testCase.verifyEmpty(setups, 'The setup list should be empty when no multi setups exist.');
end