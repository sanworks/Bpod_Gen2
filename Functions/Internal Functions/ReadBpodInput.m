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

% ReadBpodInput() reads a Bpod State Machine input channel
%
% Arguments:
% target: 'BNC', 'Wire' or 'Port'
% channel: The channel index within its type (e.g. 2 for BNC ch2)
% 
% Returns: inputStatus, 1 if high, 0 if low

function inputStatus = ReadBpodInput(target, channel)

global BpodSystem % Import the global BpodSystem object

message = 'I';
switch target
    case 'BNC'
        channel = (BpodSystem.HW.Pos.Input_BNC-2)+channel;
    case 'Wire'
        channel = (BpodSystem.HW.Pos.Input_Wire-2)+channel;
    case 'Port'
        channel = (BpodSystem.HW.Pos.Input_Port-2)+channel;
    otherwise
        error('Target must be equal to ''BNC'', ''Wire'', or ''Port''');
end
if BpodSystem.EmulatorMode == 0
    BpodSystem.SerialPort.write([message channel], 'uint8');
    inputStatus = BpodSystem.SerialPort.read(1, 'uint8');
else
    error('The IR port sensors, wire terminals and BNC connector lines cannot be directly read while in emulator mode');
end
