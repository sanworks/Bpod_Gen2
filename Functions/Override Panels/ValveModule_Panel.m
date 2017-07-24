%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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
function ValveModule_Panel(PanelHandle, ModuleName)
global BpodSystem

FontName = 'OCR A STD';
if ismac
    FontName = 'Arial';
end

%% Valve override
% Inputs
xOffset = 120;
yOffset = 110;
text(xOffset+130, yOffset+80,'Valve', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+320], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset;
for i = 1:8
    BpodSystem.GUIHandles.ValveModuleButton(i) = uicontrol('Parent', PanelHandle,'Style', 'pushbutton',...
    'String', '', 'Position', [xPos yOffset 30 30], 'Callback', @(src,event)ToggleValve(i, ModuleName),...
    'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Toggle Valve# ' num2str(i)], 'UserData', 0);
    xPos = xPos + 41;
end
xPos = xOffset+11;
for x = 1:8
    text(xPos, yOffset+45,num2str(x), 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end

function ToggleValve(valveID,ModuleName)
global BpodSystem
OldValveState = get(BpodSystem.GUIHandles.ValveModuleButton(valveID), 'UserData');
switch OldValveState
    case 0
        NewState = 1;
        ButtonFX = BpodSystem.GUIData.OnButtonDark;
        ModuleWrite(ModuleName, ['O' valveID]);
    case 1
        NewState = 0;
        ButtonFX = BpodSystem.GUIData.OffButtonDark;
        ModuleWrite(ModuleName, ['C' valveID]);
end

set(BpodSystem.GUIHandles.ValveModuleButton(valveID), 'CData', ButtonFX, 'UserData', NewState);
k = 5;