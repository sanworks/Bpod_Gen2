function DefaultBpodModule_Panel(PanelHandle, ModuleName)
global BpodSystem

FontName = 'OCR A STD';
if ismac
    FontName = 'Arial';
end
BpodSystem.GUIData.InputFontSize = 10;
BpodSystem.GUIData.InstructionFontSize = 8;
if isunix
    BpodSystem.GUIData.InstructionFontSize = 7;
end
BpodSystem.GUIData.SelectedTermDisplayMode = 1;

ModuleNumber = find(strcmp(ModuleName, BpodSystem.Modules.Name));

xOffset = 120;
yOffset = 130;
Label = ['Module ' num2str(ModuleNumber) ' Serial Terminal'];
text(xOffset+25, yOffset+80, Label, 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset-30 xOffset+360], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset;
ByteModeInstructions = 'Spaces delimit bytes, use '' '' for char i.e. ''A'' 5 213 ''B''';
MessageModeInstructions = 'Spaces delimit serial message indexes i.e. 4 22 3 128';
CharModeInstructions = 'Enter characters to send as ASCII i.e. HELLO';
ModeInstructions = {ByteModeInstructions, CharModeInstructions, MessageModeInstructions};
BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber) = uicontrol('Parent', PanelHandle,'Style', 'edit',...
    'String', CharModeInstructions, 'UserData', ModeInstructions,...
    'FontName', 'Arial', 'FontSize', BpodSystem.GUIData.InstructionFontSize,...
    'Position', [xPos-30 yOffset 275 30], 'ForegroundColor', [.5 .5 .5],...
    'HorizontalAlignment', 'left', 'Enable', 'inactive',...
    'KeyPressFcn',@(src,event)CheckForReturn(ModuleNumber, ModuleName), ...
    'ButtonDownFcn',@(src,event)ClearInstructions(ModuleNumber));
BpodSystem.GUIHandles.SerialTerminalOutput(ModuleNumber) = uicontrol('Parent', PanelHandle,'Style', 'edit',...
    'String', '', 'Position', [xPos-30 yOffset-100 275 90],...
    'HorizontalAlignment', 'left', 'Enable', 'inactive', 'Max', 3);
BpodSystem.GUIHandles.SerialTerminalButton(ModuleNumber) = uicontrol('Parent', PanelHandle,'Style', 'pushbutton',...
    'String', 'Send', 'Position', [xPos+258 yOffset 100 30], 'Callback', @(src,event)SendMessage(ModuleNumber, ModuleName));
BpodSystem.GUIHandles.SerialTerminalClearButton(ModuleNumber) = uicontrol('Parent', PanelHandle,'Style', 'pushbutton',...
    'String', 'Clear', 'Position', [xPos+258 yOffset-40 100 30], 'Callback', @(src,event)ClearTerminal(ModuleNumber));
BpodSystem.GUIHandles.SerialTerminalCharSelect(ModuleNumber) = uicontrol('Parent', PanelHandle, 'Style', 'radiobutton', ...
                           'Callback', @(src,event)SelectCharmode(ModuleNumber), ...
                           'Units',    'pixels', ...
                           'Position', [xPos-30 yOffset+40 20 20], ...
                           'String',   '', 'BackgroundColor', [.37 .37 .37], ...
                           'Value',    1);
BpodSystem.GUIHandles.SerialTerminalBytesSelect(ModuleNumber) = uicontrol('Parent', PanelHandle, 'Style', 'radiobutton', ...
                           'Callback', @(src,event)SelectBytemode(ModuleNumber), ...
                           'Units',    'pixels', ...
                           'Position', [xPos+68 yOffset+40 20 20], ...
                           'String',   '', 'BackgroundColor', [.37 .37 .37], ...
                           'Value',    0);
BpodSystem.GUIHandles.SerialTerminalMessageSelect(ModuleNumber) = uicontrol('Parent', PanelHandle, 'Style', 'radiobutton', ...
                           'Callback', @(src,event)SelectMessagemode(ModuleNumber), ...
                           'Units',    'pixels', ...
                           'Position', [xPos+165 yOffset+40 20 20], ...
                           'String',   '', 'BackgroundColor', [.37 .37 .37], ...
                           'Value',    0);
xPos = xOffset+11;
text(xPos-20, yOffset+45, 'Chars', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xPos+78, yOffset+45, 'Bytes', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xPos+175, yOffset+45, 'MessageIndexes', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);

function CheckForReturn(ModuleNumber,ModuleName)
global BpodSystem
Character = get(BpodSystem.GUIHandles.MainFig,'CurrentKey');
% if the 'return' key is pressed, send the message
if strcmp(Character,'return')
    import java.awt.Robot;
    import java.awt.event.KeyEvent;
    robot=Robot;
    robot.keyPress(KeyEvent.VK_ENTER);
    pause(0.01)
    robot.keyRelease(KeyEvent.VK_ENTER);
    SendMessage(ModuleNumber,ModuleName);
end

function SendMessage(ModuleNumber,ModuleName)
global BpodSystem
Message = get(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'String');
Format_Byte = get(BpodSystem.GUIHandles.SerialTerminalBytesSelect(ModuleNumber), 'Value');
Format_Char = get(BpodSystem.GUIHandles.SerialTerminalCharSelect(ModuleNumber), 'Value');
Format_Message = get(BpodSystem.GUIHandles.SerialTerminalMessageSelect(ModuleNumber), 'Value');
if ~isempty(Message)
    if BpodSystem.EmulatorMode == 0
        % Format message. Default = char
        if Format_Byte || Format_Message
            SpacePos = find(Message == ' ');
            nSpaces = length(SpacePos);
            ByteMessage = [];
            if nSpaces == 0
                ByteMessage = AddCandidateByte(ByteMessage,Message);
            else
                Candidate = Message(1:SpacePos(1)-1);
                ByteMessage = AddCandidateByte(ByteMessage,Candidate);
                if nSpaces == 1
                    Candidate = Message(SpacePos(end)+1:end);
                    ByteMessage = AddCandidateByte(ByteMessage,Candidate);
                elseif nSpaces > 1
                    for i = 2:nSpaces
                        Candidate = Message(SpacePos(i-1)+1:SpacePos(i)-1);
                        ByteMessage = AddCandidateByte(ByteMessage,Candidate);
                    end
                    Candidate = Message(SpacePos(end)+1:end);
                    ByteMessage = AddCandidateByte(ByteMessage,Candidate); 
                end
            end
            Message = ByteMessage;
        end
        if Format_Message
            for i = 1:length(Message)
                BpodSystem.SerialPort.write(['U' ModuleNumber Message(i)], 'uint8');
            end
        else
            ModuleWrite(ModuleName, Message);
        end
    end
end
set(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'String', '');

function ClearTerminal(ModuleNumber)
global BpodSystem
set(BpodSystem.GUIHandles.SerialTerminalOutput(ModuleNumber), 'String', '');

function SelectBytemode(ModuleNumber)
global BpodSystem
ModeInstructions = get(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'UserData');
set(BpodSystem.GUIHandles.SerialTerminalBytesSelect(ModuleNumber), 'Value', 1);
set(BpodSystem.GUIHandles.SerialTerminalMessageSelect(ModuleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalCharSelect(ModuleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'String', ModeInstructions{1},...
    'ForegroundColor', [.5 .5 .5], 'FontSize', BpodSystem.GUIData.InstructionFontSize, 'Enable', 'off');
BpodSystem.GUIData.SelectedTermDisplayMode = 2;
ClearTerminal(ModuleNumber)

function SelectCharmode(ModuleNumber)
global BpodSystem
ModeInstructions = get(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'UserData');
set(BpodSystem.GUIHandles.SerialTerminalBytesSelect(ModuleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalMessageSelect(ModuleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalCharSelect(ModuleNumber), 'Value', 1);
set(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'String', ModeInstructions{2},...
    'FontSize', BpodSystem.GUIData.InstructionFontSize, 'ForegroundColor', [.5 .5 .5], 'Enable', 'off');
BpodSystem.GUIData.SelectedTermDisplayMode = 1;
ClearTerminal(ModuleNumber)

function SelectMessagemode(ModuleNumber)
global BpodSystem

ModeInstructions = get(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'UserData');
set(BpodSystem.GUIHandles.SerialTerminalBytesSelect(ModuleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalMessageSelect(ModuleNumber), 'Value', 1);
set(BpodSystem.GUIHandles.SerialTerminalCharSelect(ModuleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'String', ModeInstructions{3},...
    'ForegroundColor', [.5 .5 .5], 'FontSize', BpodSystem.GUIData.InstructionFontSize, 'Enable', 'off');
BpodSystem.GUIData.SelectedTermDisplayMode = 3;
ClearTerminal(ModuleNumber)

function ClearInstructions(ModuleNumber)
global BpodSystem
CurrentString = get(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'String');
ModeInstructions = get(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'UserData');
if sum(strcmp(CurrentString, ModeInstructions)) > 0
    set(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'Enable', 'on', 'String', '',...
        'ForegroundColor', [0 0 0], 'FontSize', BpodSystem.GUIData.InputFontSize);
    uicontrol(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber));
end

function ByteMessage = AddCandidateByte(ByteMessage, Candidate)
if ~isempty(Candidate)
    if Candidate(1) == ''''
        CharString = Candidate(2:end-1);
        ByteMessage = [ByteMessage CharString];
    else
        CandidateByte = uint8(str2double(Candidate));
        if (CandidateByte < 255) && (CandidateByte > -1)
            ByteMessage = [ByteMessage CandidateByte];
        end
    end
end