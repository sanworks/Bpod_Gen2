function tests = test_save()
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
    folderPath = fullfile(rootPath, 'CF Regular');
    mockBpod.Path.LocalDir = folderPath;
    mkdir(folderPath)
    folderPath = fullfile(folderPath, 'Config');
    mkdir(folderPath);
    testCase.TestData.regularBpod = mockBpod;

    % Regular multi
    folderPath = fullfile(rootPath, 'CF Multi');
    mkdir(folderPath)
    mockBpod.Path.LocalDir = folderPath;
    folderPath = fullfile(folderPath, 'Config');
    mkdir(folderPath);
    mkdir(fullfile(folderPath, 'Machine-COM13'))
    mkdir(fullfile(folderPath, 'Machine-COM5'))
    testCase.TestData.multiBpod = mockBpod;
end

function teardown(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_saveLocations(testCase)
    valveManager = testCase.TestData.mockValveDataManager;
    BpodLib.calibration.liquid.io.save(valveManager.createSaveData(), 'BpodSystem', testCase.TestData.regularBpod, 'type', 'statemachine');
    testCase.verifyTrue(isfile(fullfile(testCase.TestData.regularBpod.Path.LocalDir, 'Config/LiquidCalibration.json')))

    BpodLib.calibration.liquid.io.save(valveManager.createSaveData(), 'BpodSystem', testCase.TestData.multiBpod, 'type', 'statemachine');
    testCase.verifyTrue(isfile(fullfile(testCase.TestData.multiBpod.Path.LocalDir, 'Config/Machine-COM13/LiquidCalibration.json')))
end

function test_repeatedIO(testCase)
    % Test that the values aren't changing across repeated load/saves
    valveManager = testCase.TestData.mockValveDataManager;
    n_repeats = 100;
    for i = 1:n_repeats
        BpodLib.calibration.liquid.io.save(valveManager.createSaveData(), 'BpodSystem', testCase.TestData.regularBpod, 'type', 'statemachine');
        valveManager = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.regularBpod, 'type', 'statemachine');

        % Examine the values in the loaded data
        testCase.verifyEqual(valveManager.getValve('Valve3').getValveTime(15), 110.2556502776, 'AbsTol', 1e-9)
    end

end