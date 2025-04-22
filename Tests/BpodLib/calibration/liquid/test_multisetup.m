function tests = test_multisetup()
    tests = functiontests(localfunctions);
end
function setupOnce(testCase)
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    mkdir(testCase.TestData.rootPath)

    % Create a mock ValveDataManager class
    valveManager = BpodLib.calibration.liquid.ValveDataManagerClass();
    [testFolder, ~, ~] = fileparts(mfilename('fullpath'));
    testDataFolder = fullfile(testFolder, 'testData');
    valveManager.loadData(fullfile(testDataFolder, 'ExpectedLiquidCalibration.json'))
    testCase.TestData.mockValveDataManager = valveManager;

    % Create various filesetups
    mockBpod = struct();
    mockBpod.SerialPort.Port = 'COM13';
    mockBpod.CalibrationTables.LiquidCal = valveManager;
    % Regular setup
    folderPath = fullfile(rootPath, 'CF Regular');
    mockBpod.Path.LocalDir = folderPath;
    mkdir(folderPath)
    folderPath = fullfile(folderPath, 'Calibration Files');
    mkdir(folderPath);
    testCase.TestData.regularBpod = mockBpod;
    valveManager.saveData(fullfile(folderPath, 'LiquidCalibration.json'))

    % Regular multi
    folderPath = fullfile(rootPath, 'CF Multi');
    mkdir(folderPath)
    mockBpod.Path.LocalDir = folderPath;
    folderPath = fullfile(folderPath, 'Calibration Files');
    mkdir(folderPath);
    mkdir(fullfile(folderPath, 'Machine-COM13'))
    mkdir(fullfile(folderPath, 'Machine-COM5'))
    testCase.TestData.multiBpod = mockBpod;
    valveManager.saveData(fullfile(folderPath, 'Machine-COM13/LiquidCalibration.json'))
    valveManager.saveData(fullfile(folderPath, 'Machine-COM5/LiquidCalibration.json'))

end

function teardownOnce(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_noMulti(testCase)

    % Test that data can be loaded
    ValveDataManager = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.regularBpod, 'type', 'statemachine');
    testCase.verifyTrue(isa(ValveDataManager, 'BpodLib.calibration.liquid.ValveDataManagerClass'), 'Should successfuly load the data')
end

function test_createMulti(testCase)
    BpodLib.calibration.liquid.multi.createMultiSetup(testCase.TestData.regularBpod)
    testCase.verifyTrue(isfile(fullfile(testCase.TestData.regularBpod.Path.LocalDir, 'Calibration Files/Machine-COM13/LiquidCalibration.json')),...
        'The LiquidCalibration.json should have been moved to LiqudCalibration-COM13.json')

    ValveDataManager = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.multiBpod, 'type', 'statemachine');
    testCase.verifyTrue(isa(ValveDataManager, 'BpodLib.calibration.liquid.ValveDataManagerClass'), 'Should successfuly load the data')

end

function test_isMulti(testCase)
    ValveDataManager = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.multiBpod, 'type', 'statemachine');
    testCase.verifyTrue(isa(ValveDataManager, 'BpodLib.calibration.liquid.ValveDataManagerClass'), 'Should successfuly load the data')
end
