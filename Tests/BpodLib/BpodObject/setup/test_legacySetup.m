function tests = test_legacySetup()
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

function test_convertLegacySetup(testCase)
    % Test conversion from legacy folder setup to single-folder setup

    Completed = BpodLib.BpodObject.setup.compatibility.convertSettingsFolder(testCase.TestData.BpodSystem, 'verbose', false);
    testCase.verifyTrue(Completed == 1, 'Legacy setup conversion did not complete successfully.');
    testCase.verifyTrue(isfile(fullfile(testCase.TestData.BpodSystem.Path.LocalDir, 'Settings/LiquidCalibration.json')), 'Liquid calibration file was not converted to the new format.');
    testCase.verifyTrue(isfile(fullfile(testCase.TestData.BpodSystem.Path.LocalDir, 'Settings/SoundCalibration.mat')), 'Sound calibration file was not converted to the new format.');
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
    convertedFiles = dir(fullfile(testCase.TestData.BpodSystem.Path.LocalDir, 'Settings/*.*'));
    newFiles = dir(fullfile(BpodSystemNew.Path.LocalDir, 'Settings/*.*'));
    testCase.verifyEqual(numel(convertedFiles) - 1, numel(newFiles), 'Number of files in Settings folder after conversion does not match the new setup.');
    for idx = 1:numel(newFiles)
        if convertedFiles(idx).isdir
            continue
        end
        if strcmp(convertedFiles(idx).name, 'BpodSettings.mat')
            % This file is created at startup if user modifies settings
            continue
        end
        testCase.verifyTrue(isfile(fullfile(BpodSystemNew.Path.LocalDir, 'Settings', newFiles(idx).name)), ...
            sprintf('File %s does not exist in the new setup after conversion.', newFiles(idx).name));
    end

end