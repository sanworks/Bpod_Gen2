function tests = test_createMultiSetup()
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
end

function teardown(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_isMultiSetupCOM(testCase)
    % Test if the multi setup is recognised correctly
    mockBpod = testCase.TestData.mockBpod;
    BpodLib.BpodObject.setup.updatePathAndSettings(mockBpod, 'LocalDir', testCase.TestData.LocalDir);
    testCase.verifyTrue(~BpodLib.multi.isMultiSetup(mockBpod), 'The setup should not be recognised as a multi setup before creation.');
    % Create a multi setup
    BpodLib.multi.createMultiSetup(mockBpod);
    
    % Check if the multi setup is recognised
    isMulti = BpodLib.multi.isMultiSetup(mockBpod);
    testCase.verifyTrue(isMulti, 'The setup should be recognised as a multi setup.');
end

function test_isMultiSetupEMU(testCase)
    % Test if the EMU setup is recognised as a multi setup
    mockBpod = BpodLib.BpodObject.MockBpodObject('EMU');
    BpodLib.BpodObject.setup.updatePathAndSettings(mockBpod, 'LocalDir', testCase.TestData.LocalDir);
    testCase.verifyTrue(~BpodLib.multi.isMultiSetup(mockBpod), 'The setup should not be recognised as a multi setup before creation.');
    % Create a multi setup
    BpodLib.multi.createMultiSetup(mockBpod);
    % Check if the multi setup is recognised
    isMulti = BpodLib.multi.isMultiSetup(mockBpod);
    testCase.verifyTrue(isMulti, 'The EMU setup should be recognised as a multi setup.');
end