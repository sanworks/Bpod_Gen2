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

% ModuleWrite() allows you to send messages from the state machine to its
% connected modules.
%
% Arguments:
% -moduleName: The name of the module to read from. Module names are given on the
%              system info panel, via the mangifying glass icon on the Console GUI.
% -message: The message to write to the module. This is a 1xn array of values.
% -dataType (optional): The data type to write. Default = uint8. 
%
% Returns: None
%
% Example usage: ModuleWrite('HiFi1', ['P' 0]);
% Sends bytes 'P' and 0 from the state machine to the HiFi module.

function ModuleWrite(moduleName, message, varargin)

global BpodSystem % Import the global BpodSystem object

% Resolve module index from moduleName
moduleIndex = find(strcmp(moduleName, BpodSystem.Modules.Name));
if isempty(moduleIndex)
    error(['Error: ' moduleName ' is not connected. See valid modules by running BpodSystem.Modules.']);
end

% Resolve data type to write
dataType = 'uint8';
if nargin > 2
    dataType = varargin{1};
end

% Resolve message length in bytes
nValues = length(message);
nBytes = nValues;
switch dataType
    case 'uint16'
        nBytes = nValues*2;
    case 'uint32'
        nBytes = nValues*4;
    case 'int16'
        nBytes = nValues*2;
    case 'int32'
        nBytes = nValues*4;
end

% Sanity check message length to ensure it will fit in the module serial buffer
if nBytes > 64
    error('Error: ModuleWrite can only send messages of up to 64 bytes.')
end

% Send the message
BpodSystem.SerialPort.write(['T' moduleIndex nBytes], 'uint8', message, dataType);