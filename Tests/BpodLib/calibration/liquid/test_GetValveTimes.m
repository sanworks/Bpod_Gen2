function tests = test_GetValveTimes()
    tests = functiontests(localfunctions);
end

%% Test Setup and Teardown
function setupOnce(testCase)
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
    testCase.TestData.bpodWithLegacyLiquidCal = struct();
    testCase.TestData.bpodWithLegacyLiquidCal.CalibrationTables.LiquidCal = ...
        LiquidCal;

    % Reset any persistent variables in the function
    clear GetValveTimes;
end

function teardownOnce(testCase)
    % Clean up after all tests
    clear GetValveTimes;
end

%% Test Cases
function testWithBpodSystem(testCase)
    % Test operation with BpodSystem containing ValveDataManager
    bpodSystem = testCase.TestData.bpodWithValveDataManager;
    targetValves = [1, 3];
    liquidAmount = 15;

    % Expected values based on mock implementation
    expectedTimes = [.0758261, .1102557]; 

    actualTimes = GetValveTimes(liquidAmount, targetValves, ...
        'BpodSystem', bpodSystem);

    verifyEqual(testCase, actualTimes, expectedTimes, 'AbsTol', 1e-3, ...
        'Valve times should match expected values from BpodSystem ValveDataManager');
end

function testLegacySupport(testCase)
    % Test legacy support with struct LiquidCal
    bpodSystem = testCase.TestData.bpodWithLegacyLiquidCal;
    targetValves = [1, 3];
    liquidAmount = 10;
    expectedTimes = [.0674457, .0756383]; 

    % This should trigger the legacy code path
    warning('off', 'GetValveTimes:Deprecation')
    actualTimes = GetValveTimes(liquidAmount, targetValves, ...
        'BpodSystem', bpodSystem);
    warning('on', 'GetValveTimes:Deprecation')

    verifyEqual(testCase, actualTimes, expectedTimes, 'AbsTol', 1e-3, ...
        'Valve times should match expected values from ValveDataManager');
end

% function testDeprecationWarning(testCase)
%     % Test that deprecation warning is issued for legacy LiquidCal
%     bpodSystem = testCase.TestData.bpodWithLegacyLiquidCal;
%     targetValves = 1;
%     liquidAmount = 10;
%     clear GetValveTimes
%     % Verify warning is issued
%     testCase.verifyWarning(...
%         @() GetValveTimes(liquidAmount, targetValves, 'BpodSystem', bpodSystem), ...
%         'GetValveTimes:Deprecation', ...
%         'Should warn about deprecated LiquidCal format');
% end
