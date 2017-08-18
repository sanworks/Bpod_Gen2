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
        if BpodSystem.GUIData.SelectedTermDisplayMode == 2
            CodedMessage = zeros(1,10000);
            Pos = 1;
            for i = 1:length(Message)
                ThisNum = num2str(Message(i));
                L = length(ThisNum);
                CodedMessage(Pos:Pos+L) = [ThisNum ' '];
                Pos = Pos + L + 1;
            end
            CodedMessage = CodedMessage(1:Pos);
        else
            CodedMessage = Message;
        end
        NewString = [CurrentString CodedMessage];        
        set(BpodSystem.GUIHandles.SerialTerminalOutput(BpodSystem.GUIData.CurrentPanel-1), 'String', NewString);
        drawnow;
    end
end
