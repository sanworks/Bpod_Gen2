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
    copyfile(fullfile(testCase.TestData.testDataFolder, 'LiquidCalibration.mat'), ...
             fullfile(testCase.TestData.regularBpod.Path.LocalDir, 'Calibration Files/LiquidCalibration.mat')) % copy .mat file into Calibration Files

    testCase.verifyWarning(@() BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.regularBpod, 'type', 'statemachine'), ...
        'BpodLib:LiquidCalibrationLoad:LegacyAndJSON', 'If both legacy and JSON file exist it should warn')

    delete(fullfile(testCase.TestData.regularBpod.Path.LocalDir, 'Calibration Files/LiquidCalibration.json')) % delete the default .json file
    liquidData = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.regularBpod, 'type', 'statemachine');
    testCase.verifyTrue(isstruct(liquidData), 'Should load MAT data as a struct');
end

function test_createMulti(testCase)
    % Create a multi-machine setup from a single-machine setup
    BpodLib.calibration.liquid.multi.createMultiSetup(testCase.TestData.regularBpod)

    % Test: file was moved to correct location
    testCase.verifyTrue(~isfile(fullfile(testCase.TestData.regularBpod.Path.LocalDir, 'Calibration Files/LiquidCalibration.json')),...
        'The LiquidCalibration.json should have been moved to Machine-COM13/LiquidCalibration.json')

    testCase.verifyTrue(isfile(fullfile(testCase.TestData.regularBpod.Path.LocalDir, 'Calibration Files/Machine-COM13/LiquidCalibration.json')),...
        'The LiquidCalibration.json should have been moved to Machine-COM13/LiquidCalibration.json')
    
    % Test: loader can actually find the file in its new location
    ValveDataManager = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.multiBpod, 'type', 'statemachine');
    testCase.verifyTrue(isa(ValveDataManager, 'BpodLib.calibration.liquid.ValveDataManagerClass'), 'Should successfuly load the data')
end

function test_isMulti(testCase)
    % Test functionality when the setup is a multi setup
    
    % Test successfuly loading of the liquid calibration file
    ValveDataManager = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.multiBpod, 'type', 'statemachine');
    testCase.verifyTrue(isa(ValveDataManager, 'BpodLib.calibration.liquid.ValveDataManagerClass'), 'Should successfuly load the data')
    
    % Test for warning if there's a single-setup compatible file even though the file is being loaded from multi-setup
    testCase.TestData.mockValveDataManager.saveData(fullfile(testCase.TestData.multiBpod.Path.LocalDir, 'Calibration Files/LiquidCalibration.json'))
    testCase.verifyWarning(@() BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.multiBpod, 'type', 'statemachine'), ...
        'BpodLib:LiquidCalibrationLoad:MultiAndSingle', 'Should warn about single-setup file in multi-setup environment');

end
