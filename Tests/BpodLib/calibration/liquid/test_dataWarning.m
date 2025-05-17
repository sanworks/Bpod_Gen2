function tests = test_GetValveTimes()
    tests = functiontests(localfunctions);
end

%% Test Setup and Teardown
function setup(testCase)
    % Setup test data that will be used for all tests

    % Create a mock ValveDataManager class
    valveManager = BpodLib.calibration.liquid.ValveDataManagerClass();
    [testFolder, ~, ~] = fileparts(mfilename('fullpath'));
    testDataFolder = fullfile(testFolder, 'testData');
    valveManager.loadData(fullfile(testDataFolder, 'ExpectedLiquidCalibration.json'))
    testCase.TestData.mockValveDataManager = valveManager;

    % Create a mock BpodSystem with ValveDataManager
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
end

function test_check(testCase)
    testCase.verifyTrue(strcmp(BpodLib.calibration.liquid.io.checkDefaultData(testCase.TestData.bpodWithLegacyLiquidCal.CalibrationTables.LiquidCal), 'true'), 'Function should identify old system')
end

function test_loadFailure(testCase)
    % These should "fail" silently if the startup failed to load data
    BpodLib.calibration.liquid.io.checkDefaultData([]);
    BpodLib.calibration.liquid.io.report([])
end