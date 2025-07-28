function BpodSystem = setupEmulator(varargin)
% Create a no-GUI Bpod Emulator
% BpodSystem = setupEmulator(_)
%
% Keyword Arguments
% -----------------
% LocalDir : char
%     Location of the Bpod Local/, should be a tempname
% gui : bool (default = false)
%     Use .InitializeGUI() method
%
% Returns
% -------
% BpodSystem : BpodObject
%     A BpodSystem (not assigned global) in Emulator Mode without a GUI

p = inputParser();
p.addRequired('LocalDir')
p.addParameter('gui', false)
p.parse(varargin{:})

BpodSystem = BpodObject('verbose', false);
BpodSystem.EmulatorMode = 1;
BpodLib.BpodObject.setup.updatePathAndSettings(BpodSystem, 'verbose', false, 'LocalDir', p.Results.LocalDir)
if p.Results.gui
    BpodSystem.InitializeGUI();
end
BpodSystem.SetupHardware();
BpodSystem.Status.Initialized = true;

end