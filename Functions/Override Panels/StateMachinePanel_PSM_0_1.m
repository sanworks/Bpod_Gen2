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
function StateMachinePanel_PSM_0_1
global BpodSystem

FontName = 'OCR A STD';
if ismac
    FontName = 'Arial';
end

%% BNC override
% Inputs
xOffset = 20;
yOffset = 30;
text(xOffset+8, yOffset+80,'BncIn', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+80], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset;
for i = 1:BpodSystem.HW.n.BNCInputs
    BpodSystem.GUIHandles.BNCInputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset 30 30], 'Callback', ['ManualOverride(''IB'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Spoof BNC input ' num2str(i)]);
    xPos = xPos + 41;
end
xPos = xOffset+11;
for x = 1:BpodSystem.HW.n.BNCInputs
    text(xPos, yOffset+45,num2str(x), 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end

% Outputs
xOffset = 20;
yOffset = 140;
text(xOffset+2, yOffset+80,'BncOut', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+77], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset;
for i = 1:BpodSystem.HW.n.BNCOutputs
    BpodSystem.GUIHandles.BNCOutputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset 30 30], 'Callback', ['ManualOverride(''OB'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Toggle BNC output ' num2str(i)]);
    xPos = xPos + 41;
end
xPos = xOffset+11;
for x = 1:BpodSystem.HW.n.BNCOutputs
    text(xPos, yOffset+45,num2str(x), 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end

%% Temporary filler
text(180, 190,' Bpod Pocket', 'FontName', FontName, 'FontSize', 24, 'Color', [.6 .6 .6]);
text(180, 130,'State Machine', 'FontName', FontName, 'FontSize', 24, 'Color', [.6 .6 .6]);
text(180, 70, '    v0.1', 'FontName', FontName, 'FontSize', 24, 'Color', [.6 .6 .6]);