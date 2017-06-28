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

% Resets all serial messages to equivalent byte codes (i.e. message# 4 = one byte, 0x4)
function Ack = ResetSerialMessages
global BpodSystem
if BpodSystem.EmulatorMode == 0
    BpodSystem.SerialPort.write('>', 'uint8');
    Ack = BpodSystem.SerialPort.read(1, 'uint8');
    if isempty(Ack)
        Ack = 0;
    end
else
    Ack = 1;
end