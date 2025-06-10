function tests = test_SettingsAndFiles()
    % Test that settings are setup and retrieved correctly
    % This tests BpodLib.BpodObject.setup.updatePathAndSettings and BpodLib.multi.createMultiSetup as they are closely related.
    tests = functiontests(localfunctions);
end

function setup(testCase)
    BpodSystem = BpodLib.BpodObject.MockBpodObject('COM13');
    testCase.TestData.BpodSystem = BpodSystem;

    % Setup test data that will be used for all tests
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    testCase.TestData.BpodPath = fileparts(which('Bpod'));
    mkdir(testCase.TestData.rootPath)
    LocalDir = fullfile(rootPath, 'Bpod Local');
    testCase.TestData.LocalDir = LocalDir;
end

function teardown(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_freshSingleSetup(testCase)
    BpodSystem = testCase.TestData.BpodSystem;
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', testCase.TestData.LocalDir);
    testCase.verifyTrue(strcmp(BpodSystem.Path.LocalDir, testCase.TestData.LocalDir), 'LocalDir should have been overridden to test location');
    testCase.verifyTrue(strcmp(BpodSystem.Path.SettingsDir, BpodLib.path.getPath('Config', BpodSystem)), 'SettingsDir should match expected location');
end

function test_freshMultiSetup(testCase)
    % Multi-setup created from a single setup

    % Create the single setup first
    BpodSystem = testCase.TestData.BpodSystem;
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', testCase.TestData.LocalDir);

    BpodLib.multi.createMultiSetup(BpodSystem);
    
    % Check if the multi setup was created
    settingsPath = BpodLib.path.getPath('settings', BpodSystem, 'setuptype', 'multi');
    testCase.verifyTrue(isfolder(settingsPath), 'Multi setup folder was not created.')
    
    % Check if the calibration files were created
    calibrationFolderpath = BpodLib.path.getPath('liquidcalibration', BpodSystem, 'setuptype', 'multi');
    testCase.verifyTrue(isfolder(calibrationFolderpath), 'Calibration folder was not created.')

    % Check that the settings files have been updated correctly
    testCase.verifyTrue(isa(BpodSystem.CalibrationTables.LiquidCal, 'BpodLib.calibration.liquid.ValveDataManagerClass'), ...
        'LiquidCal should be a LiquidCalibrationClass object after multi setup creation.');

end

function test_newMultiSetup(testCase)
    % Creating a multi-setup when there's an existing multi-setup
    BpodSystem = testCase.TestData.BpodSystem;
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', testCase.TestData.LocalDir); 
    BpodLib.multi.createMultiSetup(BpodSystem);
    testCase.verifyTrue(BpodLib.multi.isMultiSetup(BpodSystem), 'Multi setup should be recognised to trigger multi mode.');

    % On initialisation this should create a new multi
    NewBpodSystem = BpodLib.BpodObject.MockBpodObject('COM5');
    BpodLib.BpodObject.setup.updatePathAndSettings(NewBpodSystem, 'LocalDir', testCase.TestData.LocalDir);
    testCase.verifyTrue(isfolder(fullfile(testCase.TestData.LocalDir, 'Config/Machine-COM5')), 'Folder for new BpodSystem should exist.');
    testCase.verifyTrue(isfolder(fullfile(testCase.TestData.LocalDir, 'Config/Machine-COM13')), 'Folder for existing BpodSystem should still exist.');

    testCase.verifyTrue(numel(dir(fullfile(testCase.TestData.LocalDir, 'Config/Machine-COM5'))) == numel(dir(fullfile(testCase.TestData.LocalDir, 'Config/Machine-COM13'))), ...
        'New multi setup should have the same number of files as the existing one.');

    filelist = dir(fullfile(testCase.TestData.LocalDir, 'Config/'));
    filelist = filelist(~[filelist.isdir]);
    testCase.verifyTrue(numel(filelist) == 0, 'Settings folder should be empty of files after creating a new multi setup.');

    % Test iquidcalibration paths are set correctly
    testCase.verifyTrue(strcmp(BpodLib.path.getPath('liquidcalibration', BpodSystem), fullfile(testCase.TestData.LocalDir, 'Config/Machine-COM13')), 'Liquid calibration path should be set to the new multi setup location.');
    testCase.verifyTrue(strcmp(BpodLib.path.getPath('liquidcalibration', NewBpodSystem), fullfile(testCase.TestData.LocalDir, 'Config/Machine-COM5')), 'Liquid calibration path should be set to the new multi setup location.');
end

function test_emulatorBehaviour(testCase)
    % Test that the emulator behaves like a multi setup
    BpodSystem = testCase.TestData.BpodSystem;
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', testCase.TestData.LocalDir);
    BpodLib.multi.createMultiSetup(BpodSystem);
    
    EMUBpodSystem = BpodLib.BpodObject.MockBpodObject('EMU');
    BpodLib.BpodObject.setup.updatePathAndSettings(EMUBpodSystem, 'LocalDir', testCase.TestData.LocalDir);
    % Check if the emulator is recognised as a multi setup
    testCase.verifyTrue(BpodLib.multi.isMultiSetup(BpodSystem), 'EMU should be treated as a multi setup.');
    
    % Check if the settings directory is set correctly
    settingsPath = BpodLib.path.getPath('settings', BpodSystem, 'setuptype', 'multi');
    testCase.verifyTrue(isfolder(settingsPath), 'Settings folder for EMU should exist.');
end