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
    
    % Create test data and write JSON
    dummyValveManager = BpodLib.calibration.liquid.compatibility.createDummyData();
    dummyjsonPath = fullfile(testCase.TestData.rootPath, 'test.json');
    dummyValveManager.saveData(dummyjsonPath);
    
    % Read both files
    jsonData = fileread(dummyjsonPath);
    expectedData = fileread(testCase.TestData.expectedJSONPath);
    
    % Normalize both JSON strings
    jsonData = normalizeJSON(jsonData);
    expectedData = normalizeJSON(expectedData);
    
    % Compare the normalized versions
    testCase.verifyEqual(jsonData, expectedData, 'JSON content does not match expected');
    
    % If still failing, provide diagnostic output
    if ~isequal(jsonData, expectedData)
        fprintf('\n=== JSON COMPARISON FAILURE DETAILS ===\n');
        showDiff(jsonData, expectedData);
    end
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
    originalDateTime = datetime(testCase.TestData.OriginalLiquidCal(1).LastDateModified, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd''T''HH:mm:ss');
    testCase.verifyEqual(Valve1.LastDateModified, char(originalDateTime));
end

function test_Conversion(testCase)
    % .mat files are converted to .json files
    % Ensure that the data remains unchanged

    % Save new file
    newJSONPath = fullfile(testCase.TestData.rootPath, 'new.json');
    mockBpodSystem = struct();
    mockBpodSystem.SerialPort.PortName = 'COM1';
    [folder, ~] = fileparts(testCase.TestData.oldMATPath);
    mockBpodSystem.Path.LocalDir = folder;
    BpodLib.calibration.liquid.compatibility.convertMAT2JSON(mockBpodSystem, testCase.TestData.oldMATPath, newJSONPath);

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

function normalized = normalizeJSON(jsonStr)
    % Normalize JSON for comparison by:
    % 1. Removing modification timestamps
    % 2. Standardizing whitespace and formatting
    % 3. Sorting keys if needed
    
    % Remove variable timestamps
    normalized = regexprep(jsonStr, '"modification_datetime":\s*"[^"]*"', '"modification_datetime": ""');

    % Make all numbers have fixed precision (Windows and Linux behaviours
    % differ)
    normalized = regexprep(normalized, '(\d+\.\d{5})\d+', '$1');
    
    % Parse and re-encode to standardize formatting
    try
        data = jsondecode(normalized);
        normalized = jsonencode(data);
        normalized = strrep(normalized, '\/', '/'); % Handle path separators
    catch
        % If parsing fails, proceed with simple normalization
    end
    
    % Remove all whitespace between JSON tokens for strict comparison
    normalized = regexprep(normalized, '\s', '');
end

function showDiff(str1, str2)
    % Display the first point of difference between two strings
    minLen = min(length(str1), length(str2));
    for i = 1:minLen
        if str1(i) ~= str2(i)
            fprintf('First difference at position %d:\n', i);
            fprintf('Expected: %s\n', showChar(str2(max(1,i-10):min(end,i+10))));
            fprintf('Actual:   %s\n', showChar(str1(max(1,i-10):min(end,i+10))));
            fprintf('\nFull expected substring:\n%s\n', str2(max(1,i-20):min(end,i+20)));
            fprintf('\nFull actual substring:\n%s\n', str1(max(1,i-20):min(end,i+20)));
            break;
        end
    end
    if length(str1) ~= length(str2)
        fprintf('String length difference: expected %d, got %d\n', ...
            length(str2), length(str1));
    end
end

function out = showChar(in)
    % Display special characters visibly
    out = regexprep(in, '\n', '\\n');
    out = regexprep(out, '\t', '\\t');
    out = regexprep(out, '\r', '\\r');
end
