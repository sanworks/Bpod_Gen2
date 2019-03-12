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
function SendBpodSoftCode(Code)
global BpodSystem
if BpodSystem.Status.InStateMatrix == 1
    if Code <= BpodSystem.HW.n.SoftCodes && Code ~= 0
        BpodSystem.SerialPort.write(['~' Code-1], 'uint8');
    else
        error(['Error: cannot send soft code ' num2str(Code) '; Soft codes must be in range: [1 ' num2str(BpodSystem.HW.n.SoftCodes) '].']) 
    end
else
    error('Error sending soft code: Bpod must be running a trial.')
end
