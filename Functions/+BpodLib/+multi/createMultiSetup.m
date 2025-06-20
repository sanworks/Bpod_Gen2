function createMultiSetup(BpodSystem)
%createMultiSetup(BpodSystem)
%   This function creates a new multi setup for the Bpod system.
%   It either converts an existing single-setup folder structure to a multi-setup compatible one
%   by moving the existing files, or creates a "fresh" setup by copying in example files to where
%   the BpodSystem COM's configuration files are expected.

if BpodLib.path.compatibility.isLegacySettings(BpodSystem.Path.LocalDir)
    error('BpodLib:MultiSetup:LegacyIncompatible', 'Legacy setups must first be converted to modern setup with Config/ folder.')
end

if BpodLib.multi.isMultiSetup(BpodSystem)
    error('BpodLib:MultiSetup:ExistingMultiSetup', "This function can only be used when there are no existing multi-setups.")
end

% -- Intialising new setup
movefile(BpodLib.path.getPath('settings', BpodSystem, 'setuptype', 'single'), ...
    BpodLib.path.getPath('settings', BpodSystem, 'setuptype', 'multi'))

end