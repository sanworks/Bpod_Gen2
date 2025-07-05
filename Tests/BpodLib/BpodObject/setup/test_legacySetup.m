function tests = test_legacySetup()
    % Tests for converting legacy Bpod setup folders to the new single-folder setup
    tests = functiontests(localfunctions);
end

function setup(testCase)
    BpodSystem = BpodLib.BpodObject.MockBpodObject('COM13');
    testCase.TestData.BpodSystem = BpodSystem;

    % Setup test data that will be used for all tests
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    testCase.TestData.BpodPath = BpodLib.path.getPath('root');
    mkdir(testCase.TestData.rootPath)
    LocalDir = fullfile(rootPath, 'Bpod Local');
    testCase.TestData.LocalDir = LocalDir;

    testCase.TestData.BpodSystem.Path.LocalDir = LocalDir;

    % Construct legacy setup
    mkdir(LocalDir);
    mkdir(fullfile(LocalDir, 'Settings'));
    filenames = {'InputConfig.mat', 'ModuleUSBConfig.mat', 'SyncConfig.mat'};
    for idx = 1:numel(filenames)
        originalPath = fullfile(testCase.TestData.BpodPath, 'Examples/Example Settings Files/', filenames{idx});
        newPath = fullfile(LocalDir, 'Settings', filenames{idx});
        copyfile(originalPath, newPath);
    end
    copyfile(fullfile(testCase.TestData.BpodPath, 'Examples/Example Settings Files/BpodSettings_Example.mat'), fullfile(LocalDir, 'Settings', 'BpodSettings.mat'));

    mkdir(fullfile(LocalDir, 'Calibration Files'));
    fileNames = {'SoundCalibration.mat', 'Readme.txt'};
    for idx = 1:numel(fileNames)
        originalPath = fullfile(testCase.TestData.BpodPath, 'Examples/Example Calibration Files/', fileNames{idx});
        newPath = fullfile(LocalDir, 'Calibration Files', fileNames{idx});
        copyfile(originalPath, newPath);
    end
    originalPath = fullfile(testCase.TestData.BpodPath, 'Tests/BpodLib/calibration/liquid/testData/LiquidCalibration.mat');
    newPath = fullfile(LocalDir, 'Calibration Files', 'LiquidCalibration.mat');
    copyfile(originalPath, newPath);
end

function teardown(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_isLegacySetup(testCase)
    % Test if the setup is recognised as legacy
    BpodSystem = testCase.TestData.BpodSystem;
    isLegacy = BpodLib.path.compatibility.isLegacySettings(BpodSystem.Path.LocalDir);
    testCase.verifyTrue(isLegacy, 'The setup should be recognised as a legacy setup.');
end

function test_legacyStartup(testCase)
    BpodSystem = testCase.TestData.BpodSystem;
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', BpodSystem.Path.LocalDir)

    testCase.verifyTrue(~isfolder(fullfile(BpodSystem.Path.LocalDir, 'Config')), 'The updating should not convert legacy setups')

end

function test_createMultiSetup(testCase)
    % createMultiSetup errors when trying to convert from legacy.
    BpodSystem = testCase.TestData.BpodSystem;
    testCase.verifyError(@() BpodLib.multi.createMultiSetup(BpodSystem), 'BpodLib:MultiSetup:LegacyIncompatible', 'Should error when trying to create multi-setup from legacy setup');
end

function test_convertLegacySetup(testCase)
    % Test conversion from legacy folder setup to single-folder setup
    Completed = BpodLib.BpodObject.setup.compatibility.convertSettingsFolder(testCase.TestData.BpodSystem, 'verbose', false);
    testCase.verifyTrue(Completed == 1, 'Legacy setup conversion did not complete successfully.');
    testCase.verifyTrue(isfile(fullfile(testCase.TestData.BpodSystem.Path.LocalDir, 'Config/LiquidCalibration.json')), 'Liquid calibration file was not converted to the new format.');
    testCase.verifyTrue(isfile(fullfile(testCase.TestData.BpodSystem.Path.LocalDir, 'Config/SoundCalibration.mat')), 'Sound calibration file was not converted to the new format.');
    testCase.verifyTrue(~isfile(fullfile(testCase.TestData.BpodSystem.Path.LocalDir, 'Calibration Files/LiquidCalibration.mat')), 'Legacy liquid calibration file still exists after conversion.');
end

function test_conversionCongruence(testCase)
    % Does the conversion from legacy produce the same as the new setup?
    Completed = BpodLib.BpodObject.setup.compatibility.convertSettingsFolder(testCase.TestData.BpodSystem, 'verbose', false);

    rootPath = testCase.TestData.rootPath;
    newLocalDir = fullfile(rootPath, 'Bpod Local New');
    BpodSystemNew = BpodLib.BpodObject.MockBpodObject('COM13');
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystemNew, 'LocalDir', newLocalDir);

    % Now test to see if Bpod Local/ and Bpod Local New/ are the same
    convertedFiles = dir(fullfile(testCase.TestData.BpodSystem.Path.LocalDir, 'Config/*.*'));
    newFiles = dir(fullfile(BpodSystemNew.Path.LocalDir, 'Config/*.*'));
    testCase.verifyEqual(numel(convertedFiles) - 1, numel(newFiles), 'Number of files in Config folder after conversion does not match the new setup.');
    for idx = 1:numel(newFiles)
        if convertedFiles(idx).isdir
            continue
        end
        if strcmp(convertedFiles(idx).name, 'BpodSettings.mat')
            % This file is created at startup if user modifies settings
            continue
        end
        testCase.verifyTrue(isfile(fullfile(BpodSystemNew.Path.LocalDir, 'Config', newFiles(idx).name)), ...
            sprintf('File %s does not exist in the new setup after conversion.', newFiles(idx).name));
    end
end

function test_createBackup(testCase)
    % Test if the backup folder is created correctly
    BpodLib.BpodObject.setup.compatibility.saveSettingsBackup(testCase.TestData.BpodSystem.Path.LocalDir, 'verbose', false);
    backupFolder = fullfile(testCase.TestData.BpodSystem.Path.LocalDir, 'SettingsBackup_*');
    backupFolderExists = ~isempty(dir(backupFolder));
    testCase.verifyTrue(backupFolderExists, 'Backup folder was not created successfully.');
    
    % Check if the backup contains the expected files
    backupFiles = dir(fullfile(backupFolder, 'Settings/*.*'));
    testCase.verifyTrue(~isempty(backupFiles), 'Backup folder does not contain any files.');
end