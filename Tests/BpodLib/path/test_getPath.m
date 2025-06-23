function tests = test_getPath()
    tests = functiontests(localfunctions);
end

function setup(testCase)
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    localdir = fullfile(testCase.TestData.rootPath, 'Bpod Local');
    mkdir(localdir)
    testCase.TestData.localDir = localdir;
    
    mockBpod = BpodLib.BpodObject.MockBpodObject('COM13');
    BpodLib.BpodObject.setup.updatePathAndSettings(mockBpod, 'LocalDir', localdir)
    testCase.TestData.mockBpod = mockBpod;
    
    % Setup basic folder
    BpodLib.BpodObject.setup.updatePathAndSettings(mockBpod, 'LocalDir', localdir);

end

function teardown(testCase)
    rmdir(testCase.TestData.rootPath, 's');
end

function test_liquidcalibration(testCase)
    % Test the expected definition of liquid calibration file location
    mockBpod = testCase.TestData.mockBpod;

    % Test single setup path
    testCase.verifyEqual(BpodLib.path.getPath('liquidcalibration', mockBpod, 'setuptype', 'single'), fullfile(testCase.TestData.mockBpod.Path.LocalDir, 'Config'))
    testCase.verifyEqual(BpodLib.path.getPath('liquidcalibration', 'LocalDir', mockBpod.Path.LocalDir, 'setuptype', 'single'), fullfile(testCase.TestData.mockBpod.Path.LocalDir, 'Config'))
    
    % Test multi setup path
    testCase.verifyEqual(BpodLib.path.getPath('liquidcalibration', mockBpod, 'setuptype', 'multi'), fullfile(testCase.TestData.mockBpod.Path.LocalDir, 'Config/Machine-COM13'))
    testCase.verifyEqual(BpodLib.path.getPath('liquidcalibration', 'LocalDir', mockBpod.Path.LocalDir, 'com', 'COM13', 'setuptype', 'multi'), fullfile(testCase.TestData.mockBpod.Path.LocalDir, 'Config/Machine-COM13'))
end

function test_newCOM(testCase)
    % Test the expected definition of liquid calibration file location
    mockBpod = testCase.TestData.mockBpod;
    
    localfolder = BpodLib.path.getPath('liquidcalibration', mockBpod);
    mkdir(fullfile(localfolder, 'Machine-COM3'))
    mkdir(fullfile(localfolder, 'Machine-COM5'))
    
    testCase.verifyWarning(@() BpodLib.path.verifyPathing(mockBpod, 'verbose', false), 'BpodLib:verifyPathing:PathingIncomplete', 'Should be confused.')
end

function test_arguments_vs_auto(testCase)
    % Test that the function returns expected outputs with different combinations of arguments
    Targets = {'config', 'local', 'liquidcalibration', 'root', 'settings'};

    for target = Targets
        regularPath = BpodLib.path.getPath(target{1}, testCase.TestData.mockBpod);

        % Test with LocalDir
        localPath = BpodLib.path.getPath(target{1}, 'LocalDir', testCase.TestData.mockBpod.Path.LocalDir);
        testCase.verifyEqual(regularPath, localPath, ...
            sprintf('Path for target "%s" should match when using LocalDir.', target{1}));

        % Test with LocalDir and BpodSystem
        localBpodPath = BpodLib.path.getPath(target{1}, testCase.TestData.mockBpod, 'LocalDir', testCase.TestData.mockBpod.Path.LocalDir);
        testCase.verifyEqual(regularPath, localBpodPath, ...
            sprintf('Path for target "%s" should match when using LocalDir and BpodSystem.', target{1}));

        % Test with setuptype single
        singlePath = BpodLib.path.getPath(target{1}, testCase.TestData.mockBpod, 'setuptype', 'single');
        testCase.verifyEqual(regularPath, singlePath, ...
            sprintf('Path for target "%s" should match when using setuptype single.', target{1}));

        % Test the above but by building cell arrays of the input arguments
        LocalDirs = {[], testCase.TestData.localDir};
        SetupTypes = {[], 'single'};
        Bpods = {[], testCase.TestData.mockBpod};
        for localDir = LocalDirs
            for setupType = SetupTypes
                for bpod = Bpods
                    if isempty(bpod{1}) && isempty(localDir{1}) && ~strcmp(target{1}, 'root')
                        % Argument requires either BpodSystem or LocalDir
                        testCase.verifyError(@() BpodLib.path.getPath(target{1}, 'setuptype', setupType{1}), 'BpodLib:Path:MissingPathReference', sprintf('Should throw an error when both BpodSystem and LocalDir are empty for target "%s".', target{1}));
                        continue
                    end
                    path = BpodLib.path.getPath(target{1}, bpod{1}, 'LocalDir', localDir{1}, 'setuptype', setupType{1});
                    testCase.verifyEqual(regularPath, path, sprintf('Path for target "%s" should match with various combinations of arguments.', target{1}));
                end
            end
        end

    end
end