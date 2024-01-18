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

function psram_test(obj)
% psRAM Test
%
% This method tests the external PSRAM IC on Bpod state machine 2+
% It skips the test for state machine models without PSRAM.

global BpodSystem % Import the global BpodSystem object
obj.dispAndLog(' ');
if BpodSystem.MachineType < 4
    obj.dispAndLog('Skipping PSRAM Test, current model does not have PSRAM.');
else
    BpodSystem.SerialPort.write('_', 'uint8');
    obj.dispAndLog('Starting: PSRAM Test. This may take up to 10 seconds.');
    while BpodSystem.SerialPort.bytesAvailable < 2
        pause(.1);
    end
    memSize = BpodSystem.SerialPort.read(1, 'uint8');
    result = BpodSystem.SerialPort.read(1, 'uint8');
    if result
        obj.dispAndLog(['Test PASSED. ' num2str(memSize) ' MB detected.']);
    else
        obj.dispAndLog('Test FAILED');
    end
end