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

    % Create various file setups
    % Regular setup
    mockBpod_regular = BpodTest.MockBpodObject('COM13');
    mockBpod_regular.CalibrationTables.LiquidCal = valveManager;
    folderPath = fullfile(rootPath, 'CF Regular');
    mockBpod_regular.Path.LocalDir = folderPath;
    mkdir(folderPath)
    folderPath = fullfile(folderPath, 'Config');
    mkdir(folderPath);
    testCase.TestData.regularBpod = mockBpod_regular;

    % Regular multi
    mockBpod_multi = BpodTest.MockBpodObject('COM13');
    mockBpod_multi.CalibrationTables.LiquidCal = valveManager;
    folderPath = fullfile(rootPath, 'CF Multi');
    mkdir(folderPath)
    mockBpod_multi.Path.LocalDir = folderPath;
    folderPath = fullfile(folderPath, 'Config');
    mkdir(folderPath);
    for com = {'COM13', 'COM5'}
        mkdir(fullfile(folderPath, sprintf('Machine-%s', BpodTest.nativePort(com{1}))))
    end
    testCase.TestData.multiBpod = mockBpod_multi;
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
    testCase.verifyTrue(isfile(fullfile(testCase.TestData.multiBpod.Path.LocalDir, 'Config', sprintf('Machine-%s', BpodTest.nativePort('COM13')), 'LiquidCalibration.json')))
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