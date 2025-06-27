function tests = test_GetValveTimes()
    tests = functiontests(localfunctions);
end

%% Test Setup and Teardown
function setup(testCase)
    % Setup test data that will be used for all tests
    testCase.TestData.rootPath = tempname;
    mkdir(testCase.TestData.rootPath)

    % Create a mock ValveDataManager class, using the file used at fresh Bpod startup
    valveManager = BpodLib.calibration.liquid.ValveDataManagerClass();
    rootPath = BpodLib.path.getPath('root');
    filePath = fullfile(rootPath, 'Examples/Example Calibration Files/LiquidCalibration.json');
    valveManager.loadData(filePath)
    testCase.TestData.mockValveDataManager = valveManager;
    
    % Create a mock BpodSystem with ValveDataManager
    [testFolder, ~, ~] = fileparts(mfilename('fullpath'));
    testDataFolder = fullfile(testFolder, 'testData');
    testCase.TestData.bpodWithValveDataManager = struct();
    testCase.TestData.bpodWithValveDataManager.CalibrationTables.LiquidCal = ...
        testCase.TestData.mockValveDataManager;

    % Create a mock BpodSystem with legacy LiquidCal
    LiquidCal = load(fullfile(testDataFolder, 'LiquidCalibration.mat'), 'LiquidCal').LiquidCal;
    testCase.TestData.structCal = struct();
    testCase.TestData.bpodWithLegacyLiquidCal.CalibrationTables.LiquidCal = ...
        LiquidCal;

end

function teardown(testCase)
    % Clean up after all tests
    rmdir(testCase.TestData.rootPath, 's');
end

function test_warningWithUnmodifiedData(testCase)
    % Test that 
    testCase.verifyTrue(strcmp(BpodLib.calibration.liquid.io.checkDefaultData(testCase.TestData.bpodWithLegacyLiquidCal.CalibrationTables.LiquidCal), 'true'), 'Example legacy data should be recognised as unmodified')
    testCase.verifyTrue(strcmp(BpodLib.calibration.liquid.io.checkDefaultData(testCase.TestData.bpodWithValveDataManager.CalibrationTables.LiquidCal), 'true'), 'Example JSON data should be recognised as unmodified')
end

function test_nowarningModifiedData(testCase)
    % modify the liquid cal
    LiquidCal = testCase.TestData.bpodWithValveDataManager.CalibrationTables.LiquidCal;
    LiquidCal.getValve('Valve1').addMeasurement(10, 3)
    filepath = fullfile(testCase.TestData.rootPath, 'tempLiquidCalibration.json');
    LiquidCal.saveData(filepath)
    LiquidCal = BpodLib.calibration.liquid.ValveDataManagerClass('filepath', filepath);
    testCase.verifyTrue(strcmp(BpodLib.calibration.liquid.io.checkDefaultData(LiquidCal), 'false'), 'Modified file should be recognised as modified')
end

function test_loadFailure(testCase)
    % These should "fail" silently if the startup failed to load data
    BpodLib.calibration.liquid.io.checkDefaultData([]);
    BpodLib.calibration.liquid.io.report([])
end