function teardownBpodSystemFixture(testCase)
% Reset the BpodSystem fixture to its original state
% teardownBpodSystemFixture(testCase)
%
% Expected to be called in teardownOnce()
% Works in tandem with setupBpodSystemFixture.m

% Shut down the emulated Bpod setup if it was running
if ~testCase.TestData.Original.wasRunning
    EndBpod % clears global BpodSystem
    rmdir(testCase.TestData.Original.rootDir, 's')
end

% Restore the original BpodSystem to its original state
if testCase.TestData.Original.wasRunning
    global BpodSystem
    BpodSystem = testCase.TestData.Original.BpodSystem;
    BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'LocalDir', testCase.TestData.Original.LocalDir)
    BpodSystem.Status.Verbose = testCase.TestData.Original.Verbose;
end

end