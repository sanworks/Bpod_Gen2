%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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
function InputStatus = ReadBpodInput(Target, Channel)
% Target = 'BNC', 'Wire', 'Port'
global BpodSystem
Message = 'I';
switch Target
    case 'BNC'
        Channel = (BpodSystem.HW.Pos.Input_BNC-2)+Channel;
    case 'Wire'
        Channel = (BpodSystem.HW.Pos.Input_Wire-2)+Channel;
    case 'Port'
        Channel = (BpodSystem.HW.Pos.Input_Port-2)+Channel;
    otherwise
        error('Target must be equal to ''BNC'', ''Wire'', or ''Port''');
end
if BpodSystem.EmulatorMode == 0
    BpodSystem.SerialPort.write([Message Channel], 'uint8');
    InputStatus = BpodSystem.SerialPort.read(1, 'uint8');
else
    error('The IR port sensors, wire terminals and BNC connector lines cannot be directly read while in emulator mode');
end