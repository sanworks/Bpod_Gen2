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

function test_Bpod(testCase)
    BpodSystem = testCase.TestData.BpodSystem;
    rootFolder = BpodLib.path.getPath(BpodSystem, 'root');
    testCase.verifyTrue(isfile(fullfile(rootFolder, 'Bpod.m')), 'Should be able to find Bpod.m in the root folder') % Would fail if +BpodLib is moved
end