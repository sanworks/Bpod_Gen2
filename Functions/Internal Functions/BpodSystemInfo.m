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

% BpodSystemInfo() is launched from the console GUI, to display system information

function BpodSystemInfo

global BpodSystem % Import the global BpodSystem object

if isfield(BpodSystem.GUIHandles, 'SystemInfoFig') && ~verLessThan('MATLAB', '8.4')
    if isgraphics(BpodSystem.GUIHandles.SystemInfoFig)
        figure(BpodSystem.GUIHandles.SystemInfoFig);
        return
    end
end

fontName = 'Arial';
if ispc
    med = 12; sm = 10;
elseif ismac
    med = 14; sm = 12;
else
    med = 12; sm = 10;
end
labelFontColor = [0.9 0.9 0.9];
contentFontColor = [0 0 0];
if BpodSystem.MachineType == 4
    if BpodSystem.StateMachineInfo.nEvents > 148
        xStep = 110;
    else
        xStep = 120;
    end
    outputActionOffset = 0;
    eventOffset = 130;
elseif BpodSystem.MachineType == 3
    if BpodSystem.StateMachineInfo.nEvents > 148
        xStep = 110;
    else
        xStep = 120;
    end
    outputActionOffset = 0;
    eventOffset = 150;
else
    xStep = 130;
    if BpodSystem.StateMachineInfo.nEvents > 111
        outputActionOffset = 50;
    else
        outputActionOffset = 0;
    end
    eventOffset = 180;
end
if BpodSystem.StateMachineInfo.nEvents > 147
    xWidth = 1230;
    xfactor = 5.5;
elseif BpodSystem.StateMachineInfo.nEvents > 111
    xWidth = 1100;
    xfactor = 5.5;
else
    xWidth = 1000;
    xfactor = 8;
end
BpodSystem.GUIHandles.SystemInfoFig = figure('Position',[70 70 xWidth 600],...
    'name','Bpod System Info','numbertitle','off','MenuBar', 'none');
obj.GUIHandles.Console = axes('units','normalized', 'position',[0 0 1 1]);
            uistack(obj.GUIHandles.Console,'bottom');
            bg = imread('ConsoleBG3.bmp');
            image(bg); axis off;

appSerialPort = BpodSystem.HW.AppSerialPortName;
if isempty(appSerialPort)
    appSerialPort = '-None-';
end
            
yPos = 25; xPos = 15;
if ~ispc % Unix USB serial port names are longer
    eventOffset = eventOffset + 20;
end
text(xPos, 10,'State Machine', 'FontName', fontName, 'FontSize', med, 'Color', labelFontColor, 'FontWeight', 'Bold'); 
text(xPos, yPos,['Firmware Version: ' num2str(BpodSystem.FirmwareVersion)], 'FontSize', 11, 'FontWeight', 'Bold'); yPos = yPos + 15;
text(xPos, yPos,['Hardware: ' BpodSystem.HW.StateMachineModel], 'FontSize', med); yPos = yPos + 15;
text(xPos, yPos,['RefreshRate: ' num2str(BpodSystem.HW.CycleFrequency) 'Hz'], 'FontSize', med); yPos = yPos + 15;
text(xPos, yPos,['nModules: ' num2str(length(BpodSystem.Modules.Connected))], 'FontSize', med); yPos = yPos + 15;
text(xPos, yPos,['nBehaviorPorts: ' num2str(BpodSystem.HW.n.Ports)], 'FontSize', med); yPos = yPos + 15;
text(xPos, yPos,['nBNC I/O: ' num2str(BpodSystem.HW.n.BNCInputs) ' / ' num2str(BpodSystem.HW.n.BNCOutputs)], 'FontSize', med); yPos = yPos + 15;
text(xPos, yPos,['nWire I/O: ' num2str(BpodSystem.HW.n.WireInputs) ' / ' num2str(BpodSystem.HW.n.WireOutputs)], 'FontSize', med); yPos = yPos + 15;
text(xPos, yPos,['nFlex I/O: ' num2str(BpodSystem.HW.n.FlexIO)], 'FontSize', med); yPos = yPos + 15;
if BpodSystem.EmulatorMode == 1
    text(xPos, yPos,'FSM Serial Port: -None-', 'FontSize', med); yPos = yPos + 15;
else
    text(xPos, yPos,['FSM Serial Port: ' BpodSystem.SerialPort.PortName], 'FontSize', med); yPos = yPos + 15;
end
text(xPos, yPos,['App Serial Port: ' appSerialPort], 'FontSize', med); yPos = yPos + 25;


for i = 1:length(BpodSystem.Modules.Connected)
    text(xPos, yPos,['Module#' num2str(i)], 'Color', labelFontColor, 'FontSize', 11, 'FontWeight', 'Bold'); yPos = yPos + 15;
    if BpodSystem.Modules.Connected(i) == 1
        text(xPos, yPos, ['Name: ' BpodSystem.Modules.Name{i}], 'FontSize', med); yPos = yPos + 15;
        text(xPos, yPos, ['Firmware: v' num2str(BpodSystem.Modules.FirmwareVersion(i))], 'FontSize', med); yPos = yPos + 15;
        text(xPos, yPos, ['nEvents: ' num2str(BpodSystem.Modules.nSerialEvents(i))], 'FontSize', med); yPos = yPos + 15;
        usbPort = BpodSystem.Modules.USBport{i};
        if isempty(usbPort)
            usbPort = '-None';
        end
        text(xPos, yPos, ['USB port: ' usbPort], 'FontSize', med); yPos = yPos + 15;
    else
        text(xPos, yPos, '-Not registered-', 'FontSize', med); yPos = yPos + 15;
    end
end

yPos = 25;
xPos = xPos + eventOffset;

text(xPos, 10,'Valid Events', 'FontName', fontName, 'FontSize', med, 'Color', labelFontColor, 'FontWeight', 'Bold');
maxLen = 0;
for i = 1:BpodSystem.StateMachineInfo.nEvents
    eventText = [num2str(i) ': ' BpodSystem.StateMachineInfo.EventNames{i}];
    text(xPos, yPos,eventText,...
        'FontName', fontName, 'FontSize', sm, 'Color', contentFontColor,...
        'Interpreter', 'None');
    textLen = length(eventText);
    if textLen > maxLen
        maxLen = textLen;
    end
    yPos = yPos + 10;
    if yPos > 390
        yPos = 25; xPos = xPos + maxLen*xfactor;
        maxLen = 0;
    end
end
xPos = xPos + maxLen*6 + outputActionOffset;
text(xPos, 10,'Output Actions', 'FontName', fontName, 'FontSize', med, 'Color', labelFontColor, 'FontWeight', 'Bold');
yPos = 25; 
for i = 1:BpodSystem.StateMachineInfo.nOutputChannels
    text(xPos, yPos,[num2str(i) ': ' BpodSystem.StateMachineInfo.OutputChannelNames{i}],...
        'FontName', fontName, 'FontSize', sm, 'Color', contentFontColor,...
        'Interpreter', 'None');
    yPos = yPos + 10;
    if yPos > 390
        yPos = 25; xPos = xPos + 100;
    end
end

