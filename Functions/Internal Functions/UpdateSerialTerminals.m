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

% UpdateSerialTerminals() updates the serial terminal panels on the Bpod Console UI.
% It is called by a timer object within BpodSystem. This function should
% eventually be moved to the BpodSystem class.

function UpdateSerialTerminals

global BpodSystem % Import the global BpodSystem object

nAvailable = BpodSystem.SerialPort.bytesAvailable;
if nAvailable > 0
    message = BpodSystem.SerialPort.read(nAvailable, 'uint8');
    if BpodSystem.GUIData.CurrentPanel > 0
        currentString = get(BpodSystem.GUIHandles.SerialTerminalOutput(BpodSystem.GUIData.CurrentPanel-1), 'String');
        if length(currentString) > 256
            currentString = '';
        end
        if (BpodSystem.GUIData.SelectedTermDisplayMode == 2 || BpodSystem.GUIData.SelectedTermDisplayMode == 3)
            codedMessage = zeros(1,10000);
            pos = 1;
            for i = 1:length(message)
                thisNum = num2str(message(i));
                L = length(thisNum);
                codedMessage(pos:pos+L) = [thisNum ' '];
                pos = pos + L + 1;
            end
            codedMessage = codedMessage(1:pos-1);
        else
            codedMessage = message;
        end
        newString = [currentString codedMessage];

        set(BpodSystem.GUIHandles.SerialTerminalOutput(BpodSystem.GUIData.CurrentPanel-1), 'String', newString);
        drawnow;
    end
end
