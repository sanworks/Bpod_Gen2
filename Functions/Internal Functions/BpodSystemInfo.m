function BpodSystemInfo

global BpodSystem

FontName = 'Arial';
if ispc
    Med = 12; Sm = 10;
elseif ismac
    Med = 14; Sm = 12;
else
    Med = 12; Sm = 10;
end
LabelFontColor = [0.9 0.9 0.9];
ContentFontColor = [0 0 0];
if BpodSystem.MachineType == 3
    if BpodSystem.StateMachineInfo.nEvents > 148
        Xstep = 110;
    else
        Xstep = 120;
    end
    OutputActionOffset = 0;
    EventOffset = 150;
else
    Xstep = 130;
    if BpodSystem.StateMachineInfo.nEvents > 111
        OutputActionOffset = 50;
    else
        OutputActionOffset = 0;
    end
    EventOffset = 180;
end
if BpodSystem.StateMachineInfo.nEvents > 111
    XWidth = 1100;
    Xfactor = 5.5;
else
    XWidth = 1000;
    Xfactor = 8;
end
BpodSystem.GUIHandles.SystemInfoFig = figure('Position',[70 70 XWidth 600],...
    'name','Bpod System Info','numbertitle','off','MenuBar', 'none');
obj.GUIHandles.Console = axes('units','normalized', 'position',[0 0 1 1]);
            uistack(obj.GUIHandles.Console,'bottom');
            BG = imread('ConsoleBG3.bmp');
            image(BG); axis off;

YPos = 25; XPos = 30;
MachineTypes = {'v0.5', 'v0.7-1.0', 'v2.0'};
text(XPos, 10,'State Machine', 'FontName', FontName, 'FontSize', Med, 'Color', LabelFontColor, 'FontWeight', 'Bold'); 
text(XPos, YPos,['Firmware Version: ' num2str(BpodSystem.FirmwareVersion)], 'FontSize', 11, 'FontWeight', 'Bold'); YPos = YPos + 15;
text(XPos, YPos,['Hardware: ' MachineTypes{BpodSystem.MachineType}], 'FontSize', Med); YPos = YPos + 15;
text(XPos, YPos,['RefreshRate: ' num2str(BpodSystem.HW.CycleFrequency) 'Hz'], 'FontSize', Med); YPos = YPos + 15;
text(XPos, YPos,['nModules: ' num2str(length(BpodSystem.Modules.Connected))], 'FontSize', Med); YPos = YPos + 15;
text(XPos, YPos,['nPorts: ' num2str(BpodSystem.HW.n.Ports)], 'FontSize', Med); YPos = YPos + 15;
text(XPos, YPos,['nBNCInputs: ' num2str(BpodSystem.HW.n.BNCInputs)], 'FontSize', Med); YPos = YPos + 15;
text(XPos, YPos,['nBNCOutputs: ' num2str(BpodSystem.HW.n.BNCOutputs)], 'FontSize', Med); YPos = YPos + 15;
text(XPos, YPos,['nWireInputs: ' num2str(BpodSystem.HW.n.WireInputs)], 'FontSize', Med); YPos = YPos + 15;
text(XPos, YPos,['nWireOutputs: ' num2str(BpodSystem.HW.n.WireOutputs)], 'FontSize', Med); YPos = YPos + 25;

for i = 1:length(BpodSystem.Modules.Connected)
    text(XPos, YPos,['Module#' num2str(i)], 'Color', LabelFontColor, 'FontSize', 11, 'FontWeight', 'Bold'); YPos = YPos + 15;
    if BpodSystem.Modules.Connected(i) == 1
        text(XPos, YPos, ['Name: ' BpodSystem.Modules.Name{i}], 'FontSize', Med); YPos = YPos + 15;
        text(XPos, YPos, ['Firmware: v' num2str(BpodSystem.Modules.FirmwareVersion(i))], 'FontSize', Med); YPos = YPos + 15;
        text(XPos, YPos, ['nEvents: ' num2str(BpodSystem.Modules.nSerialEvents(i))], 'FontSize', Med); YPos = YPos + 15;
        USBport = BpodSystem.Modules.USBport{i};
        if isempty(USBport)
            USBport = '-None';
        end
        text(XPos, YPos, ['USB port: ' USBport], 'FontSize', Med); YPos = YPos + 15;
    else
        text(XPos, YPos, '-Not registered-', 'FontSize', Med); YPos = YPos + 15;
    end
end

YPos = 25;
XPos = XPos + EventOffset;

text(XPos, 10,'Valid Events', 'FontName', FontName, 'FontSize', Med, 'Color', LabelFontColor, 'FontWeight', 'Bold');
maxLen = 0;
for i = 1:BpodSystem.StateMachineInfo.nEvents
    EventText = [num2str(i) ': ' BpodSystem.StateMachineInfo.EventNames{i}];
    text(XPos, YPos,EventText,...
        'FontName', FontName, 'FontSize', Sm, 'Color', ContentFontColor,...
        'Interpreter', 'None');
    textLen = length(EventText);
    if textLen > maxLen
        maxLen = textLen;
    end
    YPos = YPos + 10;
    if YPos > 390
        YPos = 25; XPos = XPos + maxLen*Xfactor;
        maxLen = 0;
    end
end
XPos = XPos + maxLen*6 + OutputActionOffset;
text(XPos, 10,'Output Actions', 'FontName', FontName, 'FontSize', Med, 'Color', LabelFontColor, 'FontWeight', 'Bold');
YPos = 25; 
for i = 1:BpodSystem.StateMachineInfo.nOutputChannels
    text(XPos, YPos,[num2str(i) ': ' BpodSystem.StateMachineInfo.OutputChannelNames{i}],...
        'FontName', FontName, 'FontSize', Sm, 'Color', ContentFontColor,...
        'Interpreter', 'None');
    YPos = YPos + 10;
    if YPos > 390
        YPos = 25; XPos = XPos + 100;
    end
end

