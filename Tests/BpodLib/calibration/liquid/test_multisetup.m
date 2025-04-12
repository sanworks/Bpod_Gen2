function tests = test_multisetup()
    tests = functiontests(localfunctions);
end
function setupOnce(testCase)
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    mkdir(testCase.TestData.rootPath)

    % Create a mock ValveDataManager class
    valveManager = BpodLib.calibration.liquid.ValveDataManagerClass();
    [testFolder, ~, ~] = fileparts(mfilename('fullpath'));
    testDataFolder = fullfile(testFolder, 'testData');
    valveManager.loadData(fullfile(testDataFolder, 'ExpectedLiquidCalibration.json'))
    testCase.TestData.mockValveDataManager = valveManager;

    % Create various filesetups
    mockBpod = struct();
    mockBpod.SerialPort.Port = 'COM13';
    mockBpod.CalibrationTables.LiquidCal = valveManager;
    % Regular setup
    folderPath = fullfile(rootPath, 'CF Regular');
    mockBpod.Path.LocalDir = folderPath;
    mkdir(folderPath)
    folderPath = fullfile(folderPath, 'Calibration Files');
    mkdir(folderPath);
    testCase.TestData.regularBpod = mockBpod;
    valveManager.saveData(fullfile(folderPath, 'LiquidCalibration.json'))

    % Regular multi
    folderPath = fullfile(rootPath, 'CF Multi');
    mkdir(folderPath)
    mockBpod.Path.LocalDir = folderPath;
    folderPath = fullfile(folderPath, 'Calibration Files');
    mkdir(folderPath);
    testCase.TestData.multiBpod = mockBpod;
    valveManager.saveData(fullfile(folderPath, 'LiquidCalibration-COM13.json'))
    valveManager.saveData(fullfile(folderPath, 'LiquidCalibration-COM5.json'))

end

function teardownOnce(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_noMulti(testCase)
    BpodSystem = testCase.TestData.regularBpod;
    filenames = BpodLib.calibration.liquid.multi.findCalibrationFiles(BpodSystem);
    testCase.verifyTrue(numel(filenames) == 0, "Shouldn't find any potential files.")
end

function test_isMulti(testCase)
    BpodSystem = testCase.TestData.multiBpod;
    BpodSystem.Path.LocalDir
    filenames = BpodLib.calibration.liquid.multi.findCalibrationFiles(BpodSystem);
    foundcom13 = ismember('LiquidCalibration-COM13.json', filenames);
    foundcom5 = ismember('LiquidCalibration-COM5.json', filenames);
    testCase.verifyTrue(foundcom13 && foundcom5, 'Should find two files')

    ValveDataManager = BpodLib.calibration.liquid.io.load('BpodSystem', testCase.TestData.multiBpod);
    testCase.verifyTrue(isa(ValveDataManager, 'BpodLib.calibration.liquid.ValveDataManagerClass'), 'Should successfuly load the data')
end

function test_createMulti(testCase)
BpodSystem = testCase.TestData.regularBpod;
BpodLib.calibration.liquid.multi.createMultiSetup(BpodSystem)
testCase.verifyTrue(isfile(fullfile(BpodSystem.Path.LocalDir, 'Calibration Files/LiquidCalibration-COM13.json')), 'The LiquidCalibration.json should have been moved to LiqudCalibration-COM13.json')
end
