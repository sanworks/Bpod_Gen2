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
function ModuleWrite(ModuleName, Message, varargin)
% Note: This function is designed to send short byte messages to modules 
% (1-3 bytes typical, though up to 64 is permitted).
% Be sure that your module firmware can process data as fast as you send
% it with this function. If you send too much data too quickly, you may cause a buffer overflow, and
% some bytes may be dropped.
% Message is a value or a vector of values.
% An optional argument can specify a data type - uint8, uint16, uint32,
% int8, int16, int32, char
global BpodSystem
ModuleNumber = find(strcmp(ModuleName, BpodSystem.Modules.Name));
if isempty(ModuleNumber)
    error(['Error: ' ModuleName ' is not connected. See valid modules by running BpodSystem.Modules.']);
end
nValues = length(Message);
dataType = 'uint8';
if nargin > 2
    dataType = varargin{1};
end
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
if nBytes > 64
    error('Error: ModuleWrite can only send messages of up to 64 bytes. See comments in ModuleWrite.m')
end
BpodSystem.SerialPort.write(['T' ModuleNumber nBytes], 'uint8', Message, dataType);