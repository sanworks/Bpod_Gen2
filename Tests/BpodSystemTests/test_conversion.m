function tests = test_conversion()
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
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    mkdir(testCase.TestData.rootPath)
    global BpodSystem
    BpodSystem.Path.LocalDir = rootPath;
    calibrationFolder = fullfile(rootPath, '/Calibration Files/');
    testCase.TestData.calibrationFolder = calibrationFolder;

    mkdir(calibrationFolder)
    [BpodSystemTestsFolder, ~, ~] = fileparts(mfilename('fullpath'));
    [TestsFolder, ~] = fileparts(BpodSystemTestsFolder);
    testDataFolder = fullfile(TestsFolder, 'BpodLib/calibration/liquid/testData');
    testCase.TestData.testDataFolder = testDataFolder;
end

function teardown(testCase)
    rmdir(testCase.TestData.rootPath, 's')
end

function test_renames(testCase)
    % Prepare the liquid calibration folder
    copyfile(fullfile(testCase.TestData.testDataFolder, 'LiquidCalibration.mat'), fullfile(testCase.TestData.calibrationFolder, 'LiquidCalibration.mat'))
    
    % Test file actions
    global BpodSystem
    completed = BpodLib.calibration.liquid.compatibility.conversionscript(BpodSystem, 'verbose', false);
    calPath = testCase.TestData.calibrationFolder;
    matpath = fullfile(calPath, 'OLD LiquidCalibration.mat');
    jsonpath = fullfile(calPath, 'LiquidCalibration.json');
    testCase.verifyTrue(isfile(matpath))
    testCase.verifyTrue(isfile(jsonpath))
end

function test_GUItransfer(testCase)
    % Prepare the liquid calibration folder
    global BpodSystem
    copyfile(fullfile(testCase.TestData.testDataFolder, 'LiquidCalibration.mat'), fullfile(testCase.TestData.calibrationFolder, 'LiquidCalibration.mat'));
    BpodSystem.CalibrationTables.LiquidCal = load(fullfile(testCase.TestData.testDataFolder, 'LiquidCalibration.mat'), 'LiquidCal').LiquidCal;
    
    % Test GUI
    feval(get(BpodSystem.GUIHandles.SettingsButton, 'Callback')) % Click on the settings menu button
    feval(get(BpodSystem.GUIHandles.LiquidCalLaunchButton, 'Callback')) % Open up liquid calibration file
    testCase.verifyTrue(isa(BpodSystem.GUIHandles.LiquidCalibrator, 'struct'))
    close(BpodSystem.GUIHandles.LiquidCalibrator.MainFig)

    completed = BpodLib.calibration.liquid.compatibility.conversionscript(BpodSystem, 'verbose', false);
    feval(get(BpodSystem.GUIHandles.SettingsButton, 'Callback')) % Click on the settings menu button
    feval(get(BpodSystem.GUIHandles.LiquidCalLaunchButton, 'Callback')) % Open up liquid calibration file
    testCase.verifyTrue(isa(BpodSystem.GUIHandles.LiquidCalibrator, 'BpodLib.calibration.liquid.LiquidCalibratorUI'))
    close(BpodSystem.GUIHandles.LiquidCalibrator)
end