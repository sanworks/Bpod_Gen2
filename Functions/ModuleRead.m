%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2019 Sanworks LLC, Stony Brook, New York, USA

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
function Message = ModuleRead(ModuleName, nValues, varargin)
% Note: This function is designed to read short byte messages from Bpod modules 
% (1-3 bytes typical, though up to 64 is permitted).
% To read data returned from a module, the module must be set to relay
% bytes through the Bpod state machine. Turn on the module's relay first
% with BpodSystem.StartModuleRelay(MyModule). When you are done reading, be sure to
% turn the relay off with BpodSystem.StopModuleRelay() before using the state machine!

global BpodSystem
ModuleNumber = find(strcmp(ModuleName, BpodSystem.Modules.Name));
if isempty(ModuleNumber)
    error(['Error: ' ModuleName ' is not connected. See valid modules by running BpodSystem.Modules.']);
end
if BpodSystem.Modules.RelayActive(ModuleNumber) == 0
    error(['Error: the state machine must first be configured to relay bytes from ' ModuleName '. Set this with BpodSystem.StartModuleRelay(MyModule).']);
end
dataType = 'uint8';
if nargin > 2
    dataType = varargin{1};
end
Message = BpodSystem.SerialPort.read(nValues, dataType);