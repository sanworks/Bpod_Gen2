function tests = test_BpodStartup()
% Test that Bpod starts up without errors.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    BpodTest.setupBpodSystemFixture(testCase, 'gui', false);
end

function teardownOnce(testCase)
    BpodTest.teardownBpodSystemFixture(testCase);
end

function test_fullStartup(testCase)
    global BpodSystem
    BpodSystem = [];
    % verify that function Bpod() runs without error
    try
        Bpod('EMU')
        BpodTest.ui.closeMessageBoxes(BpodSystem)
    catch ME
        testCase.verifyFail(sprintf('Bpod startup failed: %s', ME.message));
    end

    % Return BpodSystem to the stored one
    EndBpod
end