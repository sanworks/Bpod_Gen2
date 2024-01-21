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

% ModuleRead() allows you to read short messages from Bpod modules, from the 
% vantage point of the state machine.
% To read data returned from a module, the state machine must be set to relay
% bytes from the module to the PC. Turn on the state machine relay first
% with BpodSystem.StartModuleRelay(MyModule). When you are done reading, be sure to
% turn the relay off with BpodSystem.StopModuleRelay() before using the state machine!
%
% Arguments:
% -moduleName: The name of the module to read from. Module names are given
%              in BpodSystem.Modules.Name
% -nValues: The number of values to read. By default, these are bytes.
% -dataType (optional): The data type to read. Default = uint8. 
%
% Returns:
% -message: The message read from the module. 
%
% Example usage: newMessage = ModuleRead('ValveModule1, 3, 'uint16');
% Read 3 16-but unsigned integers sent from the valve module to the state machine

function message = ModuleRead(moduleName, nValues, varargin)

global BpodSystem % Imports the BpodSystem object to the function workspace

% Resolve module index from moduleName
moduleIndex = find(strcmp(moduleName, BpodSystem.Modules.Name));
if isempty(moduleIndex)
    error(['Error: ' moduleName ' is not connected. See valid modules by running BpodSystem.Modules.']);
end

% Ensure that the relay is active 
if BpodSystem.Modules.RelayActive(moduleIndex) == 0
    error(['Error: the state machine must first be configured to relay bytes from ' moduleName... 
           '. Set this with BpodSystem.StartModuleRelay(MyModule).']);
end

% Resolve data type to read
dataType = 'uint8';
if nargin > 2
    dataType = varargin{1};
end

% Read message
message = BpodSystem.SerialPort.read(nValues, dataType);