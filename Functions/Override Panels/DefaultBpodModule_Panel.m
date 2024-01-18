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

% DefaultBpodModule_Panel() populates the Bpod Console GUI with a default panel for each module.
% The panel acts as a serial terminal from the vantage point of the state
% machine. Enter byte messages to send them from the state machine to the
% selected module, and view the module's responses. During a behavior
% session, module responses are interpreted as Bpod events, and are not shown.

% This file includes bug fixes and/or feature updates contributed by:
% - Florian Rau, Poulet Lab, Max Delbruck Center, Berlin Germany

function DefaultBpodModule_Panel(panelHandle, moduleName)

global BpodSystem % Import the global BpodSystem object

fontName = 'Courier New';
if ~ismac && ~ispc
    fontName = 'DejaVu Sans Mono';
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

moduleNumber = find(strcmp(moduleName, BpodSystem.Modules.Name));

xOffset = 120;
yOffset = 130;
label = ['Module ' num2str(moduleNumber) ' Serial Terminal'];
text(xOffset+25, yOffset+80, label, 'FontName', fontName, 'FontSize', BpodSystem.GUIData.TitleFontSize, 'Color', [.8 .8 .8]);
line([xOffset-30 xOffset+360], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset;
byteModeInstructions = 'Spaces delimit bytes, use '' '' for char e.g. ''A'' 5 213 ''B''';
messageModeInstructions = 'Spaces delimit serial message indexes e.g. 4 22 3 128';
charModeInstructions = 'Enter characters to send as ASCII e.g. HELLO';
modeInstructions = {byteModeInstructions, charModeInstructions, messageModeInstructions};
BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber) = uicontrol('Parent', panelHandle,'Style', 'edit',...
    'String', charModeInstructions, 'UserData', modeInstructions,...
    'FontName', 'Arial', 'FontSize', BpodSystem.GUIData.InstructionFontSize,...
    'Position', [xPos-30 yOffset 275 30], 'ForegroundColor', [.5 .5 .5],...
    'HorizontalAlignment', 'left', 'Enable', 'inactive',...
    'KeyPressFcn',@(src,event)check_for_return(moduleNumber, moduleName), ...
    'ButtonDownFcn',@(src,event)clear_instructions(moduleNumber));
BpodSystem.GUIHandles.SerialTerminalOutput(moduleNumber) = uicontrol('Parent', panelHandle,'Style', 'edit',...
    'String', '', 'Position', [xPos-30 yOffset-100 275 90],...
    'HorizontalAlignment', 'left', 'Enable', 'inactive', 'Max', 3, 'FontSize', BpodSystem.GUIData.InputFontSize);
BpodSystem.GUIHandles.SerialTerminalButton(moduleNumber) = uicontrol('Parent', panelHandle,'Style', 'pushbutton',...
    'String', 'Send', 'Position', [xPos+258 yOffset 100 30], 'Callback', @(src,event)send_message(moduleNumber, moduleName),...
    'ForegroundColor', [1 1 1], 'BackgroundColor', [0.5 0.5 0.5]);
BpodSystem.GUIHandles.SerialTerminalClearButton(moduleNumber) = uicontrol('Parent', panelHandle,'Style', 'pushbutton',...
    'String', 'Clear', 'Position', [xPos+258 yOffset-40 100 30], 'Callback', @(src,event)clear_terminal(moduleNumber),...
    'ForegroundColor', [1 1 1], 'BackgroundColor', [0.5 0.5 0.5]);
BpodSystem.GUIHandles.SerialTerminalCharSelect(moduleNumber) = uicontrol('Parent', panelHandle, 'Style', 'radiobutton', ...
                           'Callback', @(src,event)select_char_mode(moduleNumber), ...
                           'Units',    'pixels', ...
                           'Position', [xPos-30 yOffset+40 20 20], ...
                           'String',   '', 'BackgroundColor', [.37 .37 .37], ...
                           'Value',    1);
BpodSystem.GUIHandles.SerialTerminalBytesSelect(moduleNumber) = uicontrol('Parent', panelHandle, 'Style', 'radiobutton', ...
                           'Callback', @(src,event)select_byte_mode(moduleNumber), ...
                           'Units',    'pixels', ...
                           'Position', [xPos+68 yOffset+40 20 20], ...
                           'String',   '', 'BackgroundColor', [.37 .37 .37], ...
                           'Value',    0);
BpodSystem.GUIHandles.SerialTerminalMessageSelect(moduleNumber) = uicontrol('Parent', panelHandle, 'Style', 'radiobutton', ...
                           'Callback', @(src,event)select_message_mode(moduleNumber), ...
                           'Units',    'pixels', ...
                           'Position', [xPos+165 yOffset+40 20 20], ...
                           'String',   '', 'BackgroundColor', [.37 .37 .37], ...
                           'Value',    0);
xPos = xOffset+11;
text(xPos-20, yOffset+45, 'Chars', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xPos+78, yOffset+45, 'Bytes', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xPos+175, yOffset+45, 'MessageIndexes', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);

function check_for_return(ModuleNumber,ModuleName)
global BpodSystem
character = get(BpodSystem.GUIHandles.MainFig,'CurrentKey');
% if the 'return' key is pressed, send the message
if strcmp(character,'return')
    import java.awt.Robot;
    import java.awt.event.KeyEvent;
    robot=Robot;
    robot.keyPress(KeyEvent.VK_ENTER);
    pause(0.03)
    robot.keyRelease(KeyEvent.VK_ENTER);
    send_message(ModuleNumber,ModuleName);
end

function send_message(ModuleNumber,ModuleName)
global BpodSystem
message = get(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'String');
format_Byte = get(BpodSystem.GUIHandles.SerialTerminalBytesSelect(ModuleNumber), 'Value');
format_Message = get(BpodSystem.GUIHandles.SerialTerminalMessageSelect(ModuleNumber), 'Value');
if ~isempty(message)
    if BpodSystem.EmulatorMode == 0
        % Format message. Default = char
        if format_Byte || format_Message
            frags  = strsplit(message);
            isChar = ~cellfun(@isempty, regexp(frags,'^''\S*''$'));
            frags(isChar)  = cellfun(@(x) {x(2:end-1)}, frags(isChar));
            frags(~isChar) = cellfun(@(x) {str2double(x)}, frags(~isChar));
            message = uint8([frags{:}]);
        end
        if format_Message
            for i = 1:length(message)
                BpodSystem.SerialPort.write(['U' ModuleNumber message(i)], 'uint8');
            end
        else
            ModuleWrite(ModuleName, message);
        end
    end
end
set(BpodSystem.GUIHandles.SerialTerminalInput(ModuleNumber), 'String', '');

function clear_terminal(moduleNumber)
global BpodSystem
set(BpodSystem.GUIHandles.SerialTerminalOutput(moduleNumber), 'String', '');

function select_byte_mode(moduleNumber)
global BpodSystem
modeInstructions = get(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber), 'UserData');
set(BpodSystem.GUIHandles.SerialTerminalBytesSelect(moduleNumber), 'Value', 1);
set(BpodSystem.GUIHandles.SerialTerminalMessageSelect(moduleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalCharSelect(moduleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber), 'String', modeInstructions{1},...
    'ForegroundColor', [.5 .5 .5], 'FontSize', BpodSystem.GUIData.InstructionFontSize, 'Enable', 'off');
BpodSystem.GUIData.SelectedTermDisplayMode = 2;
clear_terminal(moduleNumber)

function select_char_mode(moduleNumber)
global BpodSystem
modeInstructions = get(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber), 'UserData');
set(BpodSystem.GUIHandles.SerialTerminalBytesSelect(moduleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalMessageSelect(moduleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalCharSelect(moduleNumber), 'Value', 1);
set(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber), 'String', modeInstructions{2},...
    'FontSize', BpodSystem.GUIData.InstructionFontSize, 'ForegroundColor', [.5 .5 .5], 'Enable', 'off');
BpodSystem.GUIData.SelectedTermDisplayMode = 1;
clear_terminal(moduleNumber)

function select_message_mode(moduleNumber)
global BpodSystem
modeInstructions = get(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber), 'UserData');
set(BpodSystem.GUIHandles.SerialTerminalBytesSelect(moduleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalMessageSelect(moduleNumber), 'Value', 1);
set(BpodSystem.GUIHandles.SerialTerminalCharSelect(moduleNumber), 'Value', 0);
set(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber), 'String', modeInstructions{3},...
    'ForegroundColor', [.5 .5 .5], 'FontSize', BpodSystem.GUIData.InstructionFontSize, 'Enable', 'off');
BpodSystem.GUIData.SelectedTermDisplayMode = 3;
clear_terminal(moduleNumber)

function clear_instructions(moduleNumber)
global BpodSystem
currentString = get(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber), 'String');
modeInstructions = get(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber), 'UserData');
if sum(strcmp(currentString, modeInstructions)) > 0
    set(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber), 'Enable', 'on', 'String', '',...
        'ForegroundColor', [0 0 0], 'FontSize', BpodSystem.GUIData.InputFontSize);
    uicontrol(BpodSystem.GUIHandles.SerialTerminalInput(moduleNumber));
end
