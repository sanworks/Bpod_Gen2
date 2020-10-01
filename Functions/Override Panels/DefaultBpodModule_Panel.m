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
function DefaultBpodModule_Panel(PanelHandle, ModuleName)
global BpodSystem

FontName = 'Courier New';
if ~ismac && ~ispc
    FontName = 'DejaVu Sans Mono';
end

if ispc
    BpodSystem.GUIData.InstructionFontSize = 8;
    BpodSystem.GUIData.InputFontSize = 10;
    BpodSystem.GUIData.TitleFontSize = 12;
elseif ismac
    BpodSystem.GUIData.InstructionFontSize = 11;
    BpodSystem.GUIData.InputFontSize = 12;
    BpodSystem.GUIData.TitleFontSize = 16;
else
    BpodSystem.GUIData.InstructionFontSize = 7;
    BpodSystem.GUIData.InputFontSize = 10;
    BpodSystem.GUIData.TitleFontSize = 12;
end
BpodSystem.GUIData.SelectedTermDisplayMode = 1;

ModuleNumber = find(strcmp(ModuleName, BpodSystem.Modules.Name));

xOffset = 120;
yOffset = 130;
Label = ['Module ' num2str(ModuleNumber) ' Serial Terminal'];
text(xOffset+25, yOffset+80, Label, 'FontName', FontName, 'FontSize', BpodSystem.GUIData.TitleFontSize, 'Color', [.8 .8 .8]);
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
    'HorizontalAlignment', 'left', 'Enable', 'inactive', 'Max', 3, 'FontSize', BpodSystem.GUIData.InputFontSize);
BpodSystem.GUIHandles.SerialTerminalButton(ModuleNumber) = uicontrol('Parent', PanelHandle,'Style', 'pushbutton',...
    'String', 'Send', 'Position', [xPos+258 yOffset 100 30], 'Callback', @(src,event)SendMessage(ModuleNumber, ModuleName),...
    'ForegroundColor', [1 1 1], 'BackgroundColor', [0.5 0.5 0.5]);
BpodSystem.GUIHandles.SerialTerminalClearButton(ModuleNumber) = uicontrol('Parent', PanelHandle,'Style', 'pushbutton',...
    'String', 'Clear', 'Position', [xPos+258 yOffset-40 100 30], 'Callback', @(src,event)ClearTerminal(ModuleNumber),...
    'ForegroundColor', [1 1 1], 'BackgroundColor', [0.5 0.5 0.5]);
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
    pause(0.03)
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
            frags  = strsplit(Message);
            isChar = ~cellfun(@isempty, regexp(frags,'^''\S*''$'));
            frags(isChar)  = cellfun(@(x) {x(2:end-1)}, frags(isChar));
            frags(~isChar) = cellfun(@(x) {str2double(x)}, frags(~isChar));
            Message = uint8([frags{:}]);
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
