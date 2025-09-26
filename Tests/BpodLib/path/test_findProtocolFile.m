function tests = test_findProtocolFile
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    % Setup - Create a mock directory structure
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;

    testEnvironment = BpodTest.dir.createDummyProtocolFolders(rootPath);
    testCase.TestData.protocolFolder = testEnvironment.protocolFolder;
end

function teardownOnce(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_nProtocolsFound(testCase)
    % findAllProtocols is used by findProtocolFile
    protocolFolder = testCase.TestData.protocolFolder;
    protocolStruct = BpodLib.path.findAllProtocols(protocolFolder);
    testCase.verifyEqual(length(protocolStruct), 8, 'The number of protocols found does not match the expected number.');
end

function test_basicFind(testCase)
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'Protocol_unique1', 'Protocol_unique1.m');
    resultPath = BpodLib.path.findProtocolFile(protocolFolder, 'Protocol_unique1');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');
end

function test_noMatchFail(testCase)
    protocolFolder = testCase.TestData.protocolFolder;
    testCase.verifyError(@()BpodLib.path.findProtocolFile(protocolFolder, 'Protocol_noMatch'), 'BpodLib:path:ProtocolNotFound', 'Should not be able to find protocol')
end

function test_subfolderFind(testCase)
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'subfolderB', 'Protocol_unique3', 'Protocol_unique3.m');
    resultPath = BpodLib.path.findProtocolFile(protocolFolder, 'Protocol_unique3');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');
end

function test_ambiguousMatchUNIX(testCase)
    % Test with a UNIX-style path
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'subfolderA', 'Protocol_matching1', 'Protocol_matching1.m');
    resultPath = BpodLib.path.findProtocolFile(protocolFolder, 'subfolderA/Protocol_matching1');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');
end

function test_ambiguousMatchWIN(testCase)
    % Test with a Windows-style path
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'subfolderA', 'Protocol_matching1', 'Protocol_matching1.m');
    resultPath = BpodLib.path.findProtocolFile(protocolFolder, 'subfolderA\Protocol_matching1');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');
end

function test_ambiguousMatchSubfolder(testCase)
    % Test with a subfolder that has multiple matches
    protocolFolder = testCase.TestData.protocolFolder;
    expectedPath = fullfile(protocolFolder, 'subfolderA', 'Protocol_matching2', 'Protocol_matching2.m');
    resultPath = BpodLib.path.findProtocolFile(protocolFolder, 'subfolderA/Protocol_matching2');
    testCase.verifyEqual(resultPath, expectedPath, 'The path returned by findProtocolFile does not match the expected path.');

end

function test_ambiguousMatchFail(testCase)
    % Ensure that an error is thrown when there are multiple matches
    protocolFolder = testCase.TestData.protocolFolder;
    testCase.verifyError(@()BpodLib.path.findProtocolFile(protocolFolder, 'Protocol_matching1'), 'BpodLib:path:AmbiguousProtocolMatch', 'Should be unable to return protocol path')
end

function test_subfolderAmbiguousMatchFail(testCase)
    % Ensure that an error is thrown when there are multiple matches, even across subfolders
    protocolFolder = testCase.TestData.protocolFolder;
    try
        BpodLib.path.findProtocolFile(protocolFolder, 'Protocol_matching2');
        fail('Expected findProtocolFile to throw an error for ambiguous matches, but it did not.');
    catch ME
        assert(strcmp(ME.identifier, 'BpodLib:path:AmbiguousProtocolMatch'), 'Unexpected error for ambiguous match.');
    end
end

function test_emptyFolders(testCase)
    % Top level being empty should pose no problem.
    protocolFolder = testCase.TestData.protocolFolder;
    rmdir(fullfile(protocolFolder,'Protocol_unique1'), 's')
    rmdir(fullfile(protocolFolder,'Protocol_unique2'), 's')
    rmdir(fullfile(protocolFolder,'Protocol_matching1'), 's')
    protocols = BpodLib.path.findAllProtocols(protocolFolder);
    testCase.verifyEqual(numel(protocols), 5, 'Failed to find expected number of protocols')

    % Empty intermediate folder
    bfolder = fullfile(protocolFolder, 'subfolderB');
    rmdir(fullfile(bfolder, 'Protocol_unique3'), 's')
    rmdir(fullfile(bfolder, 'Protocol_matching2'), 's')
    protocols = BpodLib.path.findAllProtocols(protocolFolder);
    testCase.verifyEqual(numel(protocols), 3, 'Failed to find expected number of protocols')
end