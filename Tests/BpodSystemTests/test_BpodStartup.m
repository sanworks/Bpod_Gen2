function tests = test_pathing()
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
    testCase.TestData.Original.wasRunning = wasRunning;
end

function teardownOnce(testCase)
    global BpodSystem
    if ~testCase.TestData.Original.wasRunning
        EndBpod
    end
end

function test_fullStartup(testCase)
    global BpodSystem
    BpodSystem = [];
    % verify that function Bpod() runs without error
    try
        Bpod('EMU')
    catch ME
        testCase.verifyFail(sprintf('Bpod startup failed: %s', ME.message));
    end

    % Return BpodSystem to the stored one
    EndBpod
    global BpodSystem
    BpodSystem = testCase.TestData.BpodSystem;
end