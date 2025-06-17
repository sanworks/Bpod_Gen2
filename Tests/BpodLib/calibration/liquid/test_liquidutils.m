function tests = test_liquidutils()
    tests = functiontests(localfunctions);
end

function setup(testCase)
    rootPath = tempname;  % Generate a unique temporary directory
    testCase.TestData.rootPath = rootPath;
    localdir = fullfile(testCase.TestData.rootPath, 'Bpod Local');
    mkdir(localdir)
    
    mockBpod = struct();
    mockBpod.SerialPort.PortName = 'COM13';
    mockBpod.Path.LocalDir = localdir;
    testCase.TestData.mockBpod = mockBpod;

    durations = [22, 66, 44, 57, 34];
    amounts = [2, 9.5, 5, 7.5, 3.5];
    valveobject = BpodLib.calibration.liquid.ValveDataClass();
    for i = 1:numel(durations)
        valveobject.addMeasurement(durations(i), amounts(i));
    end
    testCase.TestData.valveobject = valveobject;
end

function teardown(testCase)
    rmdir(testCase.TestData.rootPath, 's');
end

function test_suggestDuration(testCase)
    % Test the suggestDuration function with a mock valve object
    mockValve = testCase.TestData.valveobject;

    rangeLow = 2;
    rangeHigh = 10;

    suggestedDuration = BpodLib.calibration.liquid.utils.suggestDuration(mockValve, rangeLow, rangeHigh);
    
    % Check if the suggested duration is within the expected range
    testCase.verifyEqual(suggestedDuration, 51.128, 'AbsTol', 0.001); % Adjust tolerance as needed

    % todo: build out this test for the other cases
end