function tests = test_utils()
    tests = functiontests(localfunctions);
end

function setup(testCase)
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    mkdir(testCase.TestData.rootPath)
    
    mockBpod = BpodLib.BpodObject.MockBpodObject('COM13');
    mockBpod.Path.LocalDir = testCase.TestData.rootPath;
    testCase.TestData.mockBpod = mockBpod;
end

function teardown(testCase)
    rmdir(testCase.TestData.rootPath, 's');
end

function test_getCurrentCOM(testCase)
    testCase.verifyEqual('COM13', BpodLib.utils.getCurrentCOM(testCase.TestData.mockBpod))
    
    mockEmulatorBpod = struct();
    mockEmulatorBpod.SerialPort = [];
    testCase.verifyEqual('EMU', BpodLib.utils.getCurrentCOM(mockEmulatorBpod))

end