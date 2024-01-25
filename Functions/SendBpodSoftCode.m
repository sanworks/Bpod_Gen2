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

% SendBpodSoftCode() sends a soft code byte from the PC to the state machine.
% This byte generates a 'SoftCodeN' event which can be handled by the
% StateChangeConditions section of a state definition.
% A list of valid soft code events can be found in the
% system info panel of the Bpod console GUI (via the magnifying glass icon)
%
% Arguments: code (the soft code byte to send)
%
% Returns: None
%
% Example usage: SendBpodSoftCode(3); % Sends soft code 3 to the state
% machine, generating a 'SoftCode3' event.

function SendBpodSoftCode(code)

global BpodSystem % Import the global BpodSystem object

if BpodSystem.Status.InStateMatrix == 1
    if code <= BpodSystem.HW.n.SoftCodes && code ~= 0
        if ~BpodSystem.EmulatorMode
            bytes = ['~' code-1];
            BpodSystem.SerialPort.write(bytes, 'uint8');
        else
            bytes = ['~' code];
            BpodSystem.VirtualManualOverrideBytes = bytes;
            BpodSystem.ManualOverrideFlag = 1;
        end
    else
        error(['Error: cannot send soft code ' num2str(code) '; Soft codes must be in range: [1 '... 
               num2str(BpodSystem.HW.n.SoftCodes) '].'])
    end
else
    error('Error sending soft code: Bpod must be running a trial.')
end
