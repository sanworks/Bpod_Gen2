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

% ResetSerialMessages() resets all serial messages to equivalent byte codes 
%                       (i.e. message# 4 = one byte long, 0x4)
%
% Arguments: None
%
% Returns: ack, the acknowledgement flag. 1 if the messages were reset by the state machine, 0 if not.

function ack = ResetSerialMessages

global BpodSystem % Import the global BpodSystem object

if BpodSystem.EmulatorMode == 0
    BpodSystem.SerialPort.write('>', 'uint8');
    ack = BpodSystem.SerialPort.read(1, 'uint8');
    if isempty(ack)
        ack = 0;
    end
else
    ack = 1;
end