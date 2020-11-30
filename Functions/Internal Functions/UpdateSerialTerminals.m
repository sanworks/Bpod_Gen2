%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2020 Sanworks LLC, Rochester, New York, USA

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
function UpdateSerialTerminals
global BpodSystem
nAvailable = BpodSystem.SerialPort.bytesAvailable;
if nAvailable > 0
    Message = BpodSystem.SerialPort.read(nAvailable, 'uint8');
    if BpodSystem.GUIData.CurrentPanel > 0
        CurrentString = get(BpodSystem.GUIHandles.SerialTerminalOutput(BpodSystem.GUIData.CurrentPanel-1), 'String');
        if length(CurrentString) > 256
            CurrentString = '';
        end
        if (BpodSystem.GUIData.SelectedTermDisplayMode == 2 || BpodSystem.GUIData.SelectedTermDisplayMode == 3)
            CodedMessage = zeros(1,10000);
            Pos = 1;
            for i = 1:length(Message)
                ThisNum = num2str(Message(i));
                L = length(ThisNum);
                CodedMessage(Pos:Pos+L) = [ThisNum ' '];
                Pos = Pos + L + 1;
            end
            CodedMessage = CodedMessage(1:Pos-1);
        else
            CodedMessage = Message;
        end
        NewString = [CurrentString CodedMessage];

        set(BpodSystem.GUIHandles.SerialTerminalOutput(BpodSystem.GUIData.CurrentPanel-1), 'String', NewString);
        drawnow;
    end
end
