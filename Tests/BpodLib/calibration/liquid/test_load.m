function tests = test_load()
    tests = functiontests(localfunctions);
end

function setup(testCase)
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    mkdir(testCase.TestData.rootPath)

    % Create a mock ValveDataManager class
    valveManager = BpodLib.calibration.liquid.ValveDataManagerClass();
    [testFolder, ~, ~] = fileparts(mfilename('fullpath'));
    testDataFolder = fullfile(testFolder, 'testData');
    testCase.TestData.testDataFolder = testDataFolder;
    valveManager.loadData(fullfile(testDataFolder, 'ExpectedLiquidCalibration.json'))
    testCase.TestData.mockValveDataManager = valveManager;

    % Create various filesetups
    mockBpod = struct();
    mockBpod.SerialPort.PortName = 'COM13';
    mockBpod.CalibrationTables.LiquidCal = valveManager;
    % Regular setup
    folderPath = fullfile(rootPath, 'BL Regular');
    mockBpod.Path.LocalDir = folderPath;
    mkdir(folderPath)
    folderPath = fullfile(folderPath, 'Settings');
    mkdir(folderPath);
    testCase.TestData.regularBpod = mockBpod;
    valveManager.saveData(fullfile(folderPath, 'LiquidCalibration.json'))

    % Regular multi
    folderPath = fullfile(rootPath, 'BL Multi');
    mkdir(folderPath)
    mockBpod.Path.LocalDir = folderPath;
    folderPath = fullfile(folderPath, 'Settings');
    mkdir(folderPath);
    mkdir(fullfile(folderPath, 'Machine-COM13'))
    mkdir(fullfile(folderPath, 'Machine-COM5'))
    testCase.TestData.multiBpod = mockBpod;
    valveManager.saveData(fullfile(folderPath, 'Machine-COM13/LiquidCalibration.json'))
    valveManager.saveData(fullfile(folderPath, 'Machine-COM5/LiquidCalibration.json'))

end

function teardown(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_loadJSON(testCase)
    % Test that data can be loaded
    ValveDataManager = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.regularBpod, 'type', 'statemachine');
    testCase.verifyTrue(isa(ValveDataManager, 'BpodLib.calibration.liquid.ValveDataManagerClass'), 'Should successfuly load the data')
end

function test_loadMAT(testCase)
    % Test loading a legacy MAT file
    mkdir(fullfile(testCase.TestData.regularBpod.Path.LocalDir, 'Calibration Files'))
    copyfile(fullfile(testCase.TestData.testDataFolder, 'LiquidCalibration.mat'), ...
             fullfile(testCase.TestData.regularBpod.Path.LocalDir, 'Calibration Files/LiquidCalibration.mat')) % copy .mat file into Calibration Files

    testCase.verifyWarning(@() BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.regularBpod, 'type', 'statemachine'), ...
        'BpodLib:LiquidCalibrationLoad:LegacyAndJSON', 'If both legacy and JSON file exist it should warn')

    delete(fullfile(testCase.TestData.regularBpod.Path.LocalDir, 'Settings/LiquidCalibration.json')) % delete the default .json file
    liquidData = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.regularBpod, 'type', 'statemachine');
    testCase.verifyTrue(isstruct(liquidData), 'Should load MAT data as a struct');
end

