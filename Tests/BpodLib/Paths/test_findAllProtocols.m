function tests = test_findAllProtocols
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Setup - Create a mock directory structure
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;

    testEnvironment = initializeTestEnvironment(rootPath);
    testCase.TestData.protocolFolder = testEnvironment.protocolFolder;
end

function teardownOnce(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_nProtocolsFound(testCase)
    protocolFolder = testCase.TestData.protocolFolder;
    protocolStruct = BpodLib.paths.findAllProtocols(protocolFolder);
    testCase.verifyEqual(length(protocolStruct), 8, 'The number of protocols found does not match the expected number.');
end