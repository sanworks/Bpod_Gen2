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

% StateMachinePanel_2_0_0() sets up the state machine panel on the 
% console GUI for State Machine r2

function StateMachinePanel_2_0_0

global BpodSystem % Import the global BpodSystem object

fontName = 'Courier New';
if ~ismac && ~ispc
    fontName = 'DejaVu Sans Mono';
end
%% Port override
xOffset = 50;
yOffset = 145;
xPos = xOffset;
for i = 1:BpodSystem.HW.n.Ports
    BpodSystem.GUIHandles.PortValveButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset 30 30],... 
        'Callback', ['ManualOverride(''OV'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Toggle port ' num2str(i) ' valve']);
    BpodSystem.GUIHandles.PortLEDButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset-52 30 30],... 
        'Callback', ['ManualOverride(''OP'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Toggle port ' num2str(i) ' LED']);
    BpodSystem.GUIHandles.PortvPokeButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset-104 30 30],... 
        'Callback', ['ManualOverride(''IP'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Port ' num2str(i) ' virtual photogate']);
    xPos = xPos + 44;
end
if ispc
    medFontSize = 12;
elseif ismac
    medFontSize = 16;
else
    medFontSize = 12;
end
xPos = xOffset+10;
for x = 1:BpodSystem.HW.n.Ports
    text(xPos, yOffset+45,num2str(x), 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
    xPos = xPos + 44;
end
text(xOffset-42, yOffset+15,'VLV', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
text(xOffset-42, yOffset-38,'LED', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
text(xOffset-42, yOffset-90,'POK', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
if ispc
    titleXOffset = 20;
elseif ismac
    titleXOffset = 7;
else
    titleXOffset = 25;
end
xOffset = xOffset - 7;
text(xOffset+titleXOffset, yOffset+80,'Behavior Ports', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
line([xOffset+2 xOffset+178], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);

%% BNC override
% Inputs
xOffset = 245;
yOffset = 145;
if ispc
    titleXOffset = 13;
elseif ismac
    titleXOffset = 14;
else
    titleXOffset = 15;
end
text(xOffset+titleXOffset, yOffset+80,'BncIn', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
line([xOffset-2 xOffset+78], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
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
    text(xPos, yOffset+45,num2str(x), 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end

% Outputs
xOffset = 245;
yOffset = 40;
text(xOffset+titleXOffset-6, yOffset+80,'BncOut', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
line([xOffset-2 xOffset+78], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
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
    text(xPos, yOffset+45,num2str(x), 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end

%% Wire override
if ispc
    titleXOffset = 2;
elseif ismac
    titleXOffset = 10;
else
    titleXOffset = 2;
end
% Inputs
if BpodSystem.HW.n.WireInputs > 0
    xOffset = 395;
    yOffset = 60;
    text(xOffset+titleXOffset, yOffset+72,'WireIn', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
    line([xOffset xOffset+80], [yOffset+58 yOffset+58], 'Color', [.8 .8 .8], 'LineWidth', 2);
end
xPos = xOffset;
yPos = yOffset;
for i = 1:1:BpodSystem.HW.n.WireInputs
    BpodSystem.GUIHandles.WireInputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos yPos 30 30],... 
        'Callback', ['ManualOverride(''IW'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Spoof Wire input ' num2str(i)]);
    xPos = xPos + 41;
    if (i == 2)
        xPos = xOffset; yPos = yOffset - 55;
    end
    if i > 2
        set(BpodSystem.GUIHandles.WireInputButton(i), 'Enable', 'off');
    end
end
xPos = xOffset+12;
yPos = yOffset+42;
for i = 1:BpodSystem.HW.n.WireInputs
    text(xPos, yPos,num2str(i), 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
    if (i == 2)
        xPos = xOffset+12; yPos = yOffset - 15;
    end
end
if ispc
    titleXOffset = 0;
elseif ismac
    titleXOffset = 5;
else
    titleXOffset = 0;
end
% Outputs
if BpodSystem.HW.n.WireOutputs > 2
    xOffset = 485;
    yOffset = 60;
    text(xOffset+titleXOffset, yOffset+72,'WireOut', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
    line([xOffset xOffset+80], [yOffset+58 yOffset+58], 'Color', [.8 .8 .8], 'LineWidth', 2);
    xPos = xOffset; ypos = yOffset;
end
for i = 1:BpodSystem.HW.n.WireOutputs/2
    BpodSystem.GUIHandles.WireOutputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos ypos 30 30],... 
        'Callback', ['ManualOverride(''OW'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Toggle Wire output ' num2str(i)]);
    xPos = xPos + 41;
end
if BpodSystem.HW.n.WireOutputs > 2
    BpodSystem.GUIHandles.WireOutputButton(3) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos-82 ypos-55 30 30],... 
        'Callback', ['ManualOverride(''OW'',' num2str(3) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Toggle Wire output ' num2str(3)]);
    BpodSystem.GUIHandles.WireOutputButton(4) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),...
        'Style', 'pushbutton', 'String', '', 'Position', [xPos-41 ypos-55 30 30],... 
        'Callback', ['ManualOverride(''OW'',' num2str(4) ');'], 'CData', BpodSystem.GUIData.OffButtonDark,... 
        'TooltipString', ['Toggle Wire output ' num2str(4)], 'Enable', 'off');
end
xPos = xOffset+12;
for x = 1:BpodSystem.HW.n.WireOutputs/2
    text(xPos, yOffset+42,num2str(x), 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end
if BpodSystem.HW.n.WireOutputs > 2
    text(xOffset+13, yOffset-15,'3', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
    text(xOffset+53, yOffset-15,'4', 'FontName', fontName, 'FontSize', medFontSize, 'Color', [.8 .8 .8]);
end
xPos = [370 370 375];
if ismac
    xPos = [380 380 380];
end
if ~ispc && ~ismac
    xPos = [378 375 380];
end
smCircuitVersion = 0;
if ~isnan(BpodSystem.HW.CircuitRevision.StateMachine)
    smCircuitVersion = BpodSystem.HW.CircuitRevision.StateMachine;
end
text(xPos(1), 190,' Bpod Finite', 'FontName', fontName, 'FontSize', 16, 'Color', [.7 .7 .7]);
text(xPos(2), 130,'State Machine', 'FontName', fontName, 'FontSize', 16, 'Color', [.7 .7 .7]);
text(xPos(3), 70, ['    v2.' num2str(smCircuitVersion)], 'FontName', fontName, 'FontSize', 16, 'Color', [.7 .7 .7]);