function tests = test_getPath()
    tests = functiontests(localfunctions);
end

function setup(testCase)
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    mkdir(testCase.TestData.rootPath)
    
    mockBpod = struct();
    mockBpod.SerialPort.Port = 'COM13';
    mockBpod.Path.LocalDir = testCase.TestData.rootPath;
    testCase.TestData.mockBpod = mockBpod;
end

function teardown(testCase)
    rmdir(testCase.TestData.rootPath, 's');
end

function test_liquidcalibration(testCase)
    % Test the expected definition of liquid calibration file location
    mockBpod = testCase.TestData.mockBpod;

    % Test single setup path
    testCase.verifyEqual(BpodLib.path.getPath(mockBpod, 'liquidcalibration', 'setuptype', 'single'), fullfile(testCase.TestData.mockBpod.Path.LocalDir, 'Calibration Files'))
    
    % Test multi setup path
    testCase.verifyEqual(BpodLib.path.getPath(mockBpod, 'liquidcalibration', 'setuptype', 'multi'), fullfile(testCase.TestData.mockBpod.Path.LocalDir, 'Calibration Files/Machine-COM13'))
end