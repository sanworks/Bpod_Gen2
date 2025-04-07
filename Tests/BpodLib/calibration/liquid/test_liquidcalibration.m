function tests = test_liquidcalibration()
    tests = functiontests(localfunctions);
end
function setupOnce(testCase)
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    mkdir(testCase.TestData.rootPath)

    % -- Create dummy data
    % Create a structure using the original format
    OriginalLiquidCal = struct();
    for x = 1:8
        OriginalLiquidCal(x).Table = [];
        OriginalLiquidCal(x).Coeffs = [];
        OriginalLiquidCal(x).LastDateModified = [];
    end
    OriginalLiquidCal(1).Table = [22,2;66,9.5;44,5;57,7.5;34,3.5];
    OriginalLiquidCal(1).Coeffs = [-0.305761022808475,9.32011046949536,4.82071882423376];
    OriginalLiquidCal(1).LastDateModified = 736651.672530949;

    OriginalLiquidCal(3).Table = [22,1.5;46,5.5;59,7.5;35,3.5;66,8.5];
    OriginalLiquidCal(3).Coeffs = [0.0479777954004750,5.72402854877083,13.6002180808882];

    testCase.TestData.OriginalLiquidCal = OriginalLiquidCal;
%     testCase.TestData.expectedJSONPath = fullfile('testData/ExpectedLiquidCalibration.json');
    [testFolder, ~, ~] = fileparts(mfilename('fullpath'));
    testDataFolder = fullfile(testFolder, 'testData');
    testCase.TestData.expectedJSONPath = fullfile(testDataFolder, 'ExpectedLiquidCalibration.json');
    testCase.TestData.oldMATPath = fullfile(testDataFolder, 'LiquidCalibration.mat');
end

function teardownOnce(testCase)
    % Cleanup - Remove the directory structure after testing
    rmdir(testCase.TestData.rootPath, 's');
end

function test_JSONWrite(testCase)
    % Test that the JSON format being saved by ValveManagerClass is correct

    dummyValveManager = BpodLib.calibration.liquid.compatibility.createDummyData();
    dummyjsonPath = fullfile(testCase.TestData.rootPath, 'test.json');
    dummyValveManager.saveData(dummyjsonPath);

    % Read the JSON file
    jsonData = fileread(dummyjsonPath);

    % Read the expected JSON file
    expectedData = fileread(testCase.TestData.expectedJSONPath);

    % Compare the two
    % But remove the date-modified in meta because it's not the same
    jsonData = regexprep(jsonData, '"modification_datetime": ".*"', '"modification_datetime": ""');
    expectedData = regexprep(expectedData, '"modification_datetime": ".*"', '"modification_datetime": ""');
    testCase.verifyEqual(jsonData, expectedData);
end

function test_JSONRead(testCase)
    % Test ValveDataManager's reading, ensuring values are in the right
    % places

    % Create a ValveManager
    ValveManager = BpodLib.calibration.liquid.ValveDataManagerClass();
    ValveManager.loadData(testCase.TestData.expectedJSONPath); % this has been tested to be expected in test_JSONWrite()

    % Compare against the original data
    for x = 1:8
        valveName = sprintf('Valve%d', x);
        OriginalValve = testCase.TestData.OriginalLiquidCal(x);
        Valve = ValveManager.getValve(valveName);
        if isempty(OriginalValve.Table)
            testCase.verifyTrue(isempty(Valve.Durations));
        else
            testCase.verifyEqual(Valve.Durations, OriginalValve.Table(:,1), 'AbsTol', 1e-10);
            testCase.verifyEqual(Valve.Amounts, OriginalValve.Table(:,2), 'AbsTol', 1e-10);
            testCase.verifyEqual(Valve.Coeffs', OriginalValve.Coeffs, 'AbsTol', 1e-10);
            % Skip the date comparison because it's not the same
        end
    end

    % Verify datetime of first
    Valve1 = ValveManager.getValve('Valve1');
    originalDateTime = datetime(testCase.TestData.OriginalLiquidCal(1).LastDateModified, 'ConvertFrom', 'datenum');
    testCase.verifyEqual(Valve1.LastDateModified, char(originalDateTime));
end

function test_Conversion(testCase)
    % .mat files are converted to .json files
    % Ensure that the data remains unchanged

    % Save new file
    newJSONPath = fullfile(testCase.TestData.rootPath, 'new.json');
    BpodLib.calibration.liquid.compatibility.convertMAT2JSON(testCase.TestData.oldMATPath, newJSONPath);

    ValveManager = BpodLib.calibration.liquid.ValveDataManagerClass();
    ValveManager.loadData(newJSONPath);
        
    OriginalLiquidCal = load(testCase.TestData.oldMATPath, 'LiquidCal');
    OriginalLiquidCal = OriginalLiquidCal.LiquidCal;

    % Compare against the original data
    for x = 1:8
        valveName = sprintf('Valve%d', x);
        OriginalValve = OriginalLiquidCal(x);
        Valve = ValveManager.getValve(valveName);
        if isempty(OriginalValve.Table)
            testCase.verifyTrue(isempty(Valve.Durations));
        else
            testCase.verifyEqual(Valve.Durations, OriginalValve.Table(:,1), 'AbsTol', 1e-10);
            testCase.verifyEqual(Valve.Amounts, OriginalValve.Table(:,2), 'AbsTol', 1e-10);
            testCase.verifyEqual(Valve.Coeffs', OriginalValve.Coeffs, 'AbsTol', 1e-10);
            % Skip the date comparison because it's not the same
        end
    end

end
