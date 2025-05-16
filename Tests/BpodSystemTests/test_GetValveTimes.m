function tests = test_GetValveTimes()
% Test user interaction with GetValveTimes using a real BpodSystem object
    tests = functiontests(localfunctions);
end
    
function setupOnce(testCase)
    global BpodSystem
    wasRunning = ~isempty(BpodSystem);
    if ~wasRunning
        Bpod('EMU')
        global BpodSystem
    end
    testCase.TestData.BpodSystem = BpodSystem;
    testCase.TestData.Original.wasRunning = wasRunning;
    testCase.TestData.Original.LocalDir = BpodSystem.Path.LocalDir;
    testCase.TestData.Original.LiquidCal = BpodSystem.CalibrationTables.LiquidCal;
    testCase.TestData.Original.PortArrays = BpodSystem.CalibrationTables.PortArrays;
end

function teardownOnce(testCase)
    global BpodSystem
    BpodSystem.Path.LocalDir = testCase.TestData.Original.LocalDir;
    BpodSystem.CalibrationTables.LiquidCal = testCase.TestData.Original.LiquidCal;
    BpodSystem.CalibrationTables.PortArrays = testCase.TestData.Original.PortArrays;
    if ~testCase.TestData.Original.wasRunning
        EndBpod
    end
end

function setup(testCase)
    BpodSystem = testCase.TestData.BpodSystem;
    root = tempname;
    testCase.TestData.root = root;
    localdir = fullfile(root, 'Bpod Local');
    BpodSystem.Path.LocalDir = localdir;
    mkdir(localdir)
    mkdir(fullfile(localdir, 'Calibration Files')) 
    copyfile('../BpodLib/calibration/liquid/testData/ExpectedLiquidCalibration.json', fullfile(localdir, 'Calibration Files/LiquidCalibration.json'))
    BpodSystem.CalibrationTables.LiquidCal = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'type', 'statemachine');

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

function test_PortArrays(testCase)
    % Test that the valve times are calculated correctly
    out = GetValveTimes(5, 3, 'PortArray', 2);
    testCase.verifyEqual(out, 0.005, 'Should be able to specify port arrays', 'AbsTol', 1e-6)
end