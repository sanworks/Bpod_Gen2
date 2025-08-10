function setupBpodSystemFixture(testCase, varargin)
% Prepare a BpodSystem for testing, using an existing BpodSystem or creating a new one.
% setupBpodSystemFixture(testCase)
%
% Expected to be called in setupOnce()
% Works in tandem with teardownBpodSystemFixture.m
%
% Keyword Arguments
% -----------------
% gui : bool (default = false)
%     Startup a GUI component

p = inputParser();
p.addParameter('gui', false)
p.parse(varargin{:})

global BpodSystem
wasRunning = ~isempty(BpodSystem);
testCase.TestData.Original = struct();
testCase.TestData.Original.wasRunning = wasRunning;
if wasRunning
    assert(isa(BpodSystem, 'BpodObject'), 'BpodSystem should be a BpodObject')
    testCase.TestData.Original.BpodSystem = BpodSystem;
    testCase.TestData.Original.LocalDir = BpodSystem.Path.LocalDir; % store for restoration later
    testCase.TestData.Original.Verbose = BpodSystem.Status.Verbose;
    BpodSystem.Status.Verbose = false;
else
    % Create a new BpodSystem for testing
    % A fresh startup requires a local dir (to not contaminate existing local dir)
    localDir = fullfile(tempname, 'Bpod Local');
    mkdir(localDir)
    testCase.TestData.Original.rootDir = fileparts(localDir);
    BpodSystem = BpodTest.setupEmulator(localDir, 'gui', p.Results.gui);
end

if p.Results.gui
    assert(~isempty(BpodSystem.GUIHandles))
end

testCase.TestData.BpodSystem = BpodSystem;

end