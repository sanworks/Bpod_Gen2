function tests = test_GetValveTimes()
% Test user interaction with GetValveTimes using a real BpodSystem object
    tests = functiontests(localfunctions);
end
    
function setupOnce(testCase)
    BpodTest.setupBpodSystemFixture(testCase)
end

function teardownOnce(testCase)
    BpodTest.teardownBpodSystemFixture(testCase)
end

function setup(testCase)
    root = tempname;
    testCase.TestData.root = root;
    localdir = fullfile(root, 'Bpod Local');
    mkdir(localdir)
    
    BpodSystem = testCase.TestData.BpodSystem;
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', localdir)
;
    % -- Create port array data
    PAM = BpodLib.calibration.liquid.portarray.createValveManager(BpodSystem);
    valve = PAM.getValve('PA2_3');
    valve.addMeasurement(5, 5);
    valve.addMeasurement(10, 10);
    valve.addMeasurement(7, 7);
    BpodSystem.CalibrationTables.PortArrays = PAM;
end

function teardown(testCase)
    rmdir(testCase.TestData.root, 's')
end

function test_Function(testCase)
    % Test that the valve times are calculated correctly
    out = GetValveTimes(15, 3);
    testCase.verifyEqual(out, .1102557, 'Should grab state machine port array value', 'AbsTol', 1e-6)
end

function test_legacy(testCase)
    % Test legacy data can still be handled
    LiquidCalStruct = load('../BpodLib/calibration/liquid/testData/LiquidCalibration.mat').LiquidCal;
    testCase.TestData.BpodSystem.CalibrationTables.LiquidCal = LiquidCalStruct;
    out = GetValveTimes(15, 3);
    testCase.verifyEqual(out, .1102557, 'Should grab state machine port array value', 'AbsTol', 1e-6)
end

function test_PortArrays(testCase)
    % Test that the valve times are calculated correctly
    out = GetValveTimes(5, 3, 'PortArray', 2);
    testCase.verifyEqual(out, 0.005, 'Should be able to specify port arrays', 'AbsTol', 1e-6)
end