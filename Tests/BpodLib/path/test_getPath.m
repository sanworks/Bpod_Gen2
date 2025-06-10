function tests = test_getPath()
    tests = functiontests(localfunctions);
end

function setup(testCase)
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    localdir = fullfile(testCase.TestData.rootPath, 'Bpod Local');
    mkdir(localdir)
    
    mockBpod = struct();
    mockBpod.SerialPort.PortName = 'COM13';
    mockBpod.Path.LocalDir = localdir;
    testCase.TestData.mockBpod = mockBpod;
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
