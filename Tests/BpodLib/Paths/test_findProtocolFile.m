function tests = test_findProtocolFile
    % Refer to Tests/TestUtilities/initTestEnvironment.m for the directory structure
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

function test_basicFind(testCase)
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'Protocol_unique1', 'Protocol_unique1.m');
    resultPath = BpodLib.paths.findProtocolFile(protocolFolder, 'Protocol_unique1');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');
end

function test_noMatchFail(testCase)
    protocolFolder = testCase.TestData.protocolFolder;
    try
        BpodLib.paths.findProtocolFile(protocolFolder, 'Protocol_noMatch');
        fail('Expected findProtocolFile to throw an error for no matches, but it did not.');
    catch ME
        assert(strcmp(ME.identifier, 'BpodLib:PathNotFound'), 'Unexpected error for no match.');
    end
end

function test_subfolderFind(testCase)
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'subfolderB', 'Protocol_unique3', 'Protocol_unique3.m');
    resultPath = BpodLib.paths.findProtocolFile(protocolFolder, 'Protocol_unique3');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');
end

function test_ambiguousMatchUNIX(testCase)
    % Test with a UNIX-style path
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'subfolderA', 'Protocol_matching1', 'Protocol_matching1.m');
    resultPath = BpodLib.paths.findProtocolFile(protocolFolder, 'subfolderA/Protocol_matching1');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');
end

function test_ambiguousMatchWIN(testCase)
    % Test with a Windows-style path
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'subfolderA', 'Protocol_matching1', 'Protocol_matching1.m');
    resultPath = BpodLib.paths.findProtocolFile(protocolFolder, 'subfolderA\Protocol_matching1');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');
end

function test_ambiguousMatchSubfolder(testCase)
    % Test with a subfolder that has multiple matches
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'subfolderA', 'Protocol_matching2', 'Protocol_matching2.m');
    resultPath = BpodLib.paths.findProtocolFile(protocolFolder, 'subfolderA/Protocol_matching2');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');

end

function test_ambiguousMatchFail(testCase)
    % Ensure that an error is thrown when there are multiple matches
    protocolFolder = testCase.TestData.protocolFolder;
    try
        BpodLib.paths.findProtocolFile(protocolFolder, 'Protocol_matching1');
        fail('Expected findProtocolFile to throw an error for ambiguous matches, but it did not.');
    catch ME
        assert(strcmp(ME.identifier, 'BpodLib:AmbiguousMatch'), 'Unexpected error for ambiguous match.');
    end
end

function test_subfolderAmbiguousMatchFail(testCase)
    % Ensure that an error is thrown when there are multiple matches, even across subfolders
    protocolFolder = testCase.TestData.protocolFolder;
    try
        BpodLib.paths.findProtocolFile(protocolFolder, 'Protocol_matching2');
        fail('Expected findProtocolFile to throw an error for ambiguous matches, but it did not.');
    catch ME
        assert(strcmp(ME.identifier, 'BpodLib:AmbiguousMatch'), 'Unexpected error for ambiguous match.');
    end
end


