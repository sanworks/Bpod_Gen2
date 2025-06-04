function tests = test_settings()
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
    testCase.verifyTrue(strcmp(BpodSystem.Path.SettingsDir, BpodLib.path.getPath(BpodSystem, 'Settings')), 'SettingsDir should match expected location');
end

function test_freshMultiSetup(testCase)
    % Multi-setup created froma single setup

    % Create the single setup first
    BpodSystem = testCase.TestData.BpodSystem;
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', testCase.TestData.LocalDir);

    BpodLib.multi.createMultiSetup(BpodSystem);
    
    % Check if the multi setup was created
    settingsPath = BpodLib.path.getPath(BpodSystem, 'settings', 'setuptype', 'multi');
    testCase.verifyTrue(isfolder(settingsPath), 'Multi setup folder was not created.')
    
    % Check if the calibration files were created
    calibrationFolderpath = BpodLib.path.getPath(BpodSystem, 'liquidcalibration', 'setuptype', 'multi');
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
    testCase.verifyTrue(isfolder(fullfile(testCase.TestData.LocalDir, 'Settings/Machine-COM5')), 'Folder for new BpodSystem should exist.');
    testCase.verifyTrue(isfolder(fullfile(testCase.TestData.LocalDir, 'Settings/Machine-COM13')), 'Folder for existing BpodSystem should still exist.');

    testCase.verifyTrue(numel(dir(fullfile(testCase.TestData.LocalDir, 'Settings/Machine-COM5'))) == numel(dir(fullfile(testCase.TestData.LocalDir, 'Settings/Machine-COM13'))), ...
        'New multi setup should have the same number of files as the existing one.');

    filelist = dir(fullfile(testCase.TestData.LocalDir, 'Settings/'));
    filelist = filelist(~[filelist.isdir]);
    testCase.verifyTrue(numel(filelist) == 0, 'Settings folder should be empty of files after creating a new multi setup.');
end
% todo: test for EMU being treated as a bona fide multi setup