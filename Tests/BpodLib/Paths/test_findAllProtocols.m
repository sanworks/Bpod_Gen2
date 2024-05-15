function tests = test_findAllProtocols
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Setup - Create a mock directory structure
    rootPath = tempname;  % Generate a unique temporary directory
    protocolFolder = fullfile(rootPath, 'Bpod Local/Protocols');

    initializeTestEnvironment(rootPath)

    testCase.TestData.rootPath = rootPath;
    testCase.TestData.protocolFolder = protocolFolder;
end

function teardownOnce(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_nProtocolsFound(testCase)
    protocolFolder = testCase.TestData.protocolFolder;
    protocolStruct = BpodLib.paths.findAllProtocols(protocolFolder);
    testCase.verifyEqual(length(protocolStruct), 7, 'The number of protocols found does not match the expected number.');
end