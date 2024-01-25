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

% StateMachinePanel_0_5() sets up the state machine panel on the 
% console GUI for State Machine r0.5

function StateMachinePanel_0_5

global BpodSystem % Import the global BpodSystem object

fontName = 'Courier New';
if ~ismac && ~ispc
    fontName = 'DejaVu Sans Mono';
end
%% Port override
xOffset = 50;
yOffset = 150;
xPos = xOffset;
for i = 1:BpodSystem.HW.n.Ports
    BpodSystem.GUIHandles.PortValveButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset 30 30],... 
        'Callback', ['ManualOverride(''OV'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Toggle port ' num2str(i) ' valve']);
    BpodSystem.GUIHandles.PortLEDButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset-45 30 30],... 
        'Callback', ['ManualOverride(''OP'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Toggle port ' num2str(i) ' LED']);
    BpodSystem.GUIHandles.PortvPokeButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset-90 30 30],... 
        'Callback', ['ManualOverride(''IP'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Port ' num2str(i) ' virtual photogate']);
    xPos = xPos + 41;
end
xPos = xOffset+10;
for x = 1:BpodSystem.HW.n.Ports
    text(xPos, yOffset+45,num2str(x), 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end
text(xOffset-42, yOffset+15,'VLV', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xOffset-42, yOffset-30,'LED', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xOffset-42, yOffset-75,'POK', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);

text(xOffset+80, yOffset+80,'Behavior Ports', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+320], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);

%% BNC override
% Inputs
xOffset = 395;
yOffset = 150;
text(xOffset+6, yOffset+80,'BncIn', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+80], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset;
for i = 1:BpodSystem.HW.n.BNCInputs
    BpodSystem.GUIHandles.BNCInputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset 30 30],... 
        'Callback', ['ManualOverride(''IB'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Spoof BNC input ' num2str(i)]);
    xPos = xPos + 41;
end
xPos = xOffset+11;
for x = 1:BpodSystem.HW.n.BNCInputs
    text(xPos, yOffset+45,num2str(x), 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end

% Outputs
xOffset = 485;
yOffset = 150;
text(xOffset+5, yOffset+80,'BncOut', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+80], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset;
for i = 1:BpodSystem.HW.n.BNCOutputs
    BpodSystem.GUIHandles.BNCOutputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset 30 30],... 
        'Callback', ['ManualOverride(''OB'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Toggle BNC output ' num2str(i)]);
    xPos = xPos + 41;
end
xPos = xOffset+11;
for x = 1:BpodSystem.HW.n.BNCOutputs
    text(xPos, yOffset+45,num2str(x), 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end

%% Wire override
% Inputs
xOffset = 395;
yOffset = 60;
text(xOffset+2, yOffset+72,'WireIn', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+80], [yOffset+58 yOffset+58], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset;
yPos = yOffset;
for i = 1:BpodSystem.HW.n.WireInputs
    BpodSystem.GUIHandles.WireInputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yPos 30 30],... 
        'Callback', ['ManualOverride(''IW'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Spoof Wire input ' num2str(i)]);
    xPos = xPos + 41;
    if (i == 2)
        xPos = xOffset; yPos = yOffset - 55;
    end
end
xPos = xOffset+12;
yPos = yOffset+42;
for i = 1:BpodSystem.HW.n.WireInputs
    text(xPos, yPos,num2str(i), 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
    if (i == 2)
        xPos = xOffset+12; yPos = yOffset - 15;
    end
end

% Outputs
xOffset = 485;
yOffset = 60;
text(xOffset, yOffset+72,'WireOut', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+80], [yOffset+58 yOffset+58], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset; ypos = yOffset;
for i = 1:2
    BpodSystem.GUIHandles.WireOutputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos ypos 30 30],... 
        'Callback', ['ManualOverride(''OW'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Toggle Wire output ' num2str(i)]);
    xPos = xPos + 41;
end
BpodSystem.GUIHandles.WireOutputButton(3) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
    'Style', 'pushbutton', 'String', '', 'Position', [xPos-82 ypos-55 30 30],... 
    'Callback', ['ManualOverride(''OW'',' num2str(3) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
    'TooltipString', ['Toggle Wire output ' num2str(3)]);
BpodSystem.GUIHandles.WireOutputButton(4) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
    'Style', 'pushbutton', 'String', '', 'Position', [xPos-41 ypos-55 30 30],... 
    'Callback', ['ManualOverride(''OW'',' num2str(4) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
    'TooltipString', ['Toggle Wire output ' num2str(4)]);

xPos = xOffset+12;
for x = 1:2
    text(xPos, yOffset+42,num2str(x), 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end
text(xOffset+13, yOffset-15,'3', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xOffset+53, yOffset-15,'4', 'FontName', fontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
