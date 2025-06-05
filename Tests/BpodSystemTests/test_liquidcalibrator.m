function tests = test_liquidcalibrator()
% Test the user interactions of liquid calibration.
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
    testCase.TestData.Original = struct();
    testCase.TestData.Original.wasRunning = wasRunning;
    testCase.TestData.Original.LocalDir = BpodSystem.Path.LocalDir;
    testCase.TestData.Original.LiquidCal = BpodSystem.CalibrationTables.LiquidCal;
end

function teardownOnce(testCase)
    global BpodSystem
    BpodSystem.Path.LocalDir = testCase.TestData.Original.LocalDir;
    BpodSystem.CalibrationTables.LiquidCal = testCase.TestData.Original.LiquidCal;
    if ~testCase.TestData.Original.wasRunning
        EndBpod
    end
end

function setup(testCase)
    global BpodSystem
    root = tempname;
    testCase.TestData.root = root;
    localdir = fullfile(root, 'Bpod Local');
    BpodSystem.Path.LocalDir = localdir;
    mkdir(localdir)
    mkdir(fullfile(localdir, 'Calibration Files'))
    mkdir(fullfile(localdir, 'Settings'))
    mkdir(fullfile(localdir, 'Config'))
    copyfile('../BpodLib/calibration/liquid/testData/ExpectedLiquidCalibration.json', fullfile(localdir, 'Config/LiquidCalibration.json'))
    copyfile('../BpodLib/calibration/liquid/testData/LiquidCalibration.mat', fullfile(localdir, 'Calibration Files/OLD LiquidCalibration.mat'))
    BpodSystem.CalibrationTables.LiquidCal = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'type', 'statemachine');
end

function teardown(testCase)
    rmdir(testCase.TestData.root, 's')
end

function test_RunCalibration(testCase)
    % Test users running a calibration

    global BpodSystem
    
    % Make sure there's no existing liquid calibration window when about to
    % start test
    if isfield(BpodSystem.GUIHandles, 'LiquidCalibrator') && ~isempty(BpodSystem.GUIHandles.LiquidCalibrator)
        close(BpodSystem.GUIHandles.LiquidCalibrator)
    end

    % User opens liquid calibration
    feval(get(BpodSystem.GUIHandles.SettingsButton, 'Callback')) % Click on the settings menu button
    feval(get(BpodSystem.GUIHandles.LiquidCalLaunchButton, 'Callback')) % Open up liquid calibration file
    testCase.verifyTrue(isa(BpodSystem.GUIHandles.LiquidCalibrator, 'BpodLib.calibration.liquid.LiquidCalibratorUI'))

    lc = BpodSystem.GUIHandles.LiquidCalibrator;

    % Verify that existing data is as expected, for sanity
    testCase.verifyEqual(BpodSystem.CalibrationTables.LiquidCal.getValve('Valve3').getValveTime(5), 43.420, 'AbsTol', 1e-2)  
  
    % Select Valve 3
    lc.GUIHandles.ValveSelector.Value = 3;
    feval(lc.GUIHandles.ValveSelector.Callback, [], [])
    
    % Click add measurements
    feval(lc.GUIHandles.AddMeasurementButton.Callback, [], [])

    % Add time time for ms to keep valve open
    lc.GUIHandles.AmountEntry.String = '40';
    feval(lc.GUIHandles.OkButton.Callback, [], [])

    % Request running of measurement
    feval(lc.GUIHandles.MeasurePendingButton.Callback, [], [])
    feval(lc.GUIHandles.OkButton.Callback, [], [])

    % Measurement runs

    lc.GUIHandles.CB3b.String = '.8'; % enter value weighed
    feval(lc.GUIHandles.EnterMeasurementButton2.Callback, [], []) % click OK button

    close(lc.GUIHandles.msgbox) % close box that confirms saving

    % Test update to liquidcal stored inside BpodSystem
    testCase.verifyEqual(BpodSystem.CalibrationTables.LiquidCal.getValve('Valve3').getValveTime(5), 42.507, 'AbsTol', 1e-2)

    % Test GetValveTimes returns expected value
    testCase.verifyEqual(GetValveTimes(5, 3), 42.507 / 1000, 'AbsTol', 1e-2)

    % Test file is saved appropriately
    savedliquid = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'type', 'statemachine');
    testCase.verifyEqual(savedliquid.getValve('Valve3').getValveTime(5), 42.507, 'AbsTol', 1e-2)

    close(BpodSystem.GUIHandles.LiquidCalibrator)
end

function test_GUItransfer(testCase)
    % Test that the GUI can be transferred from the old format to the new
    % Prepare the liquid calibration folder
    global BpodSystem
    calFolder = fullfile(BpodSystem.Path.LocalDir, 'Calibration Files');
    convertedCalFolder = fullfile(BpodSystem.Path.LocalDir, 'Config');
    copyfile(fullfile(calFolder, 'OLD LiquidCalibration.mat'), fullfile(calFolder, 'LiquidCalibration.mat'));
    copyfile(fullfile(convertedCalFolder, 'LiquidCalibration.json'), fullfile(convertedCalFolder, 'TEMP LiquidCalibration.json'));
    BpodSystem.CalibrationTables.LiquidCal = load(fullfile(calFolder, 'LiquidCalibration.mat'), 'LiquidCal').LiquidCal;
    
    % Test GUI
    feval(get(BpodSystem.GUIHandles.SettingsButton, 'Callback')) % Click on the settings menu button
    feval(get(BpodSystem.GUIHandles.LiquidCalLaunchButton, 'Callback')) % Open up liquid calibration file
    testCase.verifyTrue(isa(BpodSystem.GUIHandles.LiquidCalibrator, 'struct'), 'UI should be legacy struct/func system')
    close(BpodSystem.GUIHandles.LiquidCalibrator.MainFig)

    completed = BpodLib.calibration.liquid.compatibility.conversionscript(BpodSystem, 'verbose', false);
    BpodSystem.CalibrationTables.LiquidCal = BpodLib.calibration.liquid.io.load('BpodSystem', BpodSystem, 'type', 'statemachine');
    feval(get(BpodSystem.GUIHandles.SettingsButton, 'Callback')) % Click on the settings menu button
    feval(get(BpodSystem.GUIHandles.LiquidCalLaunchButton, 'Callback')) % Open up liquid calibration file
    testCase.verifyTrue(isa(BpodSystem.GUIHandles.LiquidCalibrator, 'BpodLib.calibration.liquid.LiquidCalibratorUI'), 'UI should be the object')
    close(BpodSystem.GUIHandles.LiquidCalibrator)
end