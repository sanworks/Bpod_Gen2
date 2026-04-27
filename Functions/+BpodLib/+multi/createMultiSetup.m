function createMultiSetup(BpodSystem)
% Create a new multi setup inside Bpod Local/
% createMultiSetup(BpodSystem)
%
% This function creates a new multi setup for the Bpod system.
% It either converts an existing single-setup folder structure to a multi-setup compatible one
% by moving the existing files, or creates a "fresh" setup by copying in example files to where
% the BpodSystem COM's configuration files are expected.

%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

if BpodLib.path.compatibility.isLegacySettings(BpodSystem.Path.LocalDir)
    error('BpodLib:MultiSetup:LegacyIncompatible', ['Legacy config setup detected. It must first be converted to the modern setup.'... 
        newline 'Close Bpod, Rename your /Bpod Local/ folder to /Bpod Local Backup/, run Bpod and start any protocol.'...
        newline 'Then close Bpod and copy your existing protocols and data from your backup to the new Bpod Local folder.'... 
        newline 'You will need to re-configure any settings and re-run calibration. Then re-run BpodSystem.createMultiSetup'])
end

if BpodLib.multi.isMultiSetup(BpodSystem)
    error('BpodLib:MultiSetup:ExistingMultiSetup', "This function can only be used when there are no existing multi-setups.")
end

% -- Intialising new setup
movefile(BpodLib.path.getPath('settings', BpodSystem, 'setuptype', 'single'), ...
    BpodLib.path.getPath('settings', BpodSystem, 'setuptype', 'multi'))

end