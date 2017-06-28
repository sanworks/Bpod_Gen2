function StateMachinePanel_0_7
global BpodSystem

FontName = 'OCR A STD';
if ismac
    FontName = 'Arial';
end
%% Port override
xOffset = 50;
yOffset = 150;
xPos = xOffset;
for i = 1:BpodSystem.HW.n.Ports
    BpodSystem.GUIHandles.PortValveButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset 30 30], 'Callback', ['ManualOverride(''OS'',1,' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Toggle port ' num2str(i) ' valve']);
    BpodSystem.GUIHandles.PortLEDButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset-45 30 30], 'Callback', ['ManualOverride(''OP'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Toggle port ' num2str(i) ' LED']);
    BpodSystem.GUIHandles.PortvPokeButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),'Style', 'pushbutton', 'String', '', 'Position', [xPos yOffset-90 30 30], 'Callback', ['ManualOverride(''IP'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Port ' num2str(i) ' virtual photogate']);
    xPos = xPos + 41;
end
xPos = xOffset+10;
for x = 1:BpodSystem.HW.n.Ports
    text(xPos, yOffset+45,num2str(x), 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end
text(xOffset-42, yOffset+15,'VLV', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xOffset-42, yOffset-30,'LED', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xOffset-42, yOffset-75,'POK', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);

text(xOffset+80, yOffset+80,'Behavior Ports', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+320], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);

%% BNC override
% Inputs
xOffset = 395;
yOffset = 150;
text(xOffset+6, yOffset+80,'BncIn', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
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
xOffset = 485;
yOffset = 150;
text(xOffset+5, yOffset+80,'BncOut', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+80], [yOffset+65 yOffset+65], 'Color', [.8 .8 .8], 'LineWidth', 2);
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

%% Wire override
% Inputs
xOffset = 395;
yOffset = 60;
text(xOffset+2, yOffset+72,'WireIn', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+80], [yOffset+58 yOffset+58], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset;
yPos = yOffset;
for i = 1:4
    BpodSystem.GUIHandles.WireInputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),'Style', 'pushbutton', 'String', '', 'Position', [xPos yPos 30 30], 'Callback', ['ManualOverride(''IW'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Spoof Wire input ' num2str(i)]);
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
for i = 1:4
    text(xPos, yPos,num2str(i), 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
    if (i == 2)
        xPos = xOffset+12; yPos = yOffset - 15;
    end
end

% Outputs
xOffset = 485;
yOffset = 60;
text(xOffset, yOffset+72,'WireOut', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
line([xOffset xOffset+80], [yOffset+58 yOffset+58], 'Color', [.8 .8 .8], 'LineWidth', 2);
xPos = xOffset; ypos = yOffset;
for i = 1:2
    BpodSystem.GUIHandles.WireOutputButton(i) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),'Style', 'pushbutton', 'String', '', 'Position', [xPos ypos 30 30], 'Callback', ['ManualOverride(''OW'',' num2str(i) ');'], 'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Toggle Wire output ' num2str(i)]);
    xPos = xPos + 41;
end
BpodSystem.GUIHandles.WireOutputButton(3) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),'Style', 'pushbutton', 'String', '', 'Position', [xPos-82 ypos-55 30 30], 'Callback', ['ManualOverride(''OW'',' num2str(3) ');'], 'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Toggle Wire output ' num2str(3)]);
BpodSystem.GUIHandles.WireOutputButton(4) = uicontrol('Parent', BpodSystem.GUIHandles.OverridePanel(1),'Style', 'pushbutton', 'String', '', 'Position', [xPos-41 ypos-55 30 30], 'Callback', ['ManualOverride(''OW'',' num2str(4) ');'], 'CData', BpodSystem.GUIData.OffButtonDark, 'TooltipString', ['Toggle Wire output ' num2str(4)], 'Enable', 'off');

xPos = xOffset+12;
for x = 1:2
    text(xPos, yOffset+42,num2str(x), 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
    xPos = xPos + 41;
end
text(xOffset+13, yOffset-15,'3', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
text(xOffset+53, yOffset-15,'4', 'FontName', FontName, 'FontSize', 12, 'Color', [.8 .8 .8]);
