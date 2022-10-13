%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

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
function ConfigureModuleUSB(junk, morejunk)
global BpodSystem

if isfield(BpodSystem.GUIHandles, 'ModuleUSBFig') && ~verLessThan('MATLAB', '8.4')
    if isgraphics(BpodSystem.GUIHandles.ModuleUSBFig)
        figure(BpodSystem.GUIHandles.ModuleUSBFig);
        return
    end
end

FontName = 'Courier New';
if ~ismac && ~ispc
    FontName = 'DejaVu Sans Mono';
end
if BpodSystem.EmulatorMode == 0
    BpodSystem.GUIHandles.ModuleUSBFig = figure('Position',[600 400 600 250],'name','Module USB config.','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
    ha = axes('units','normalized', 'position',[0 0 1 1]);
    uistack(ha,'bottom');
    BG = imread('InputChannelConfig2.bmp');
    image(BG); axis off;
    text(130, 15, 'Module USB config', 'FontName', FontName, 'FontSize', 15, 'Color', [0.8 0.8 0.8]);
    text(15, 35, 'Module', 'FontName', FontName, 'FontSize', 14, 'Color', [0.8 0.8 0.8]);
    text(140, 35, 'USB Port', 'FontName', FontName, 'FontSize', 14, 'Color', [0.8 0.8 0.8]);
    text(265, 35, 'USB Available', 'FontName', FontName, 'FontSize', 14, 'Color', [0.8 0.8 0.8]);
    BpodSystem.GUIHandles.ModuleList = uicontrol('Position', [20 75 180 100], 'Style', 'listbox', 'String', BpodSystem.Modules.Name, 'FontSize', 12,...
        'FontName', 'Courier', 'FontWeight', 'Bold', 'Callback', @selectFromModuleList);
    BpodSystem.GUIHandles.PairedUSBList = uicontrol('Position', [210 75 180 100], 'Style', 'listbox', 'String', {''},...
        'FontSize', 12, 'FontName', 'Courier', 'FontWeight', 'Bold', 'Callback', @selectFromPairedList);
    BpodSystem.GUIHandles.FreeUSBList = uicontrol('Position', [400 75 180 100], 'Style', 'listbox', 'String', {''},...
        'FontSize', 12, 'FontName', 'Courier', 'FontWeight', 'Bold');
    BpodSystem.GUIHandles.ModuleUSBPairButton = uicontrol('Position', [130 20 150 30], 'Style', 'pushbutton', 'String', '-->Pair<--', 'FontSize', 12, 'FontName', 'Courier', 'Callback', @pair);
    BpodSystem.GUIHandles.ModuleUSBUnpairButton = uicontrol('Position', [320 20 150 30], 'Style', 'pushbutton', 'String', '<--Unpair-->', 'FontSize', 12, 'FontName', 'Courier', 'Callback', @unpair);
    refreshFreeUSBPorts;
end
function pair(junk, moreJunk)
global BpodSystem
selectedModule = get(BpodSystem.GUIHandles.ModuleList, 'Value');
moduleNames = get(BpodSystem.GUIHandles.ModuleList, 'String');
selectedModuleName = moduleNames{selectedModule};
selectedfreeUSB = get(BpodSystem.GUIHandles.FreeUSBList, 'Value');
if (~isempty(selectedfreeUSB))
    pairedUSBNames = get(BpodSystem.GUIHandles.PairedUSBList, 'String');
    freeUSBNames = get(BpodSystem.GUIHandles.FreeUSBList, 'String');
    if ~isempty(freeUSBNames)
        selectedUSBName = freeUSBNames{selectedfreeUSB};
        BpodSystem.Modules.USBport{selectedModule} = selectedUSBName;
        pairedUSBNames{selectedModule} = selectedUSBName;
        freeUSBNames = freeUSBNames(logical(1-strcmp(freeUSBNames, selectedUSBName)));
        set(BpodSystem.GUIHandles.PairedUSBList, 'String', pairedUSBNames);
        set(BpodSystem.GUIHandles.FreeUSBList, 'Value', 1);
        set(BpodSystem.GUIHandles.FreeUSBList, 'String', freeUSBNames);
        BpodSystem.ModuleUSB.(selectedModuleName) = selectedUSBName;
    end
end
SaveModuleUSBConfig;

function unpair(junk, moreJunk)
global BpodSystem
selectedModule = get(BpodSystem.GUIHandles.ModuleList, 'Value');
moduleNames = get(BpodSystem.GUIHandles.ModuleList, 'String');
selectedModuleName = moduleNames{selectedModule};
BpodSystem.Modules.USBport{selectedModule} = [];
refreshFreeUSBPorts;
if isfield(BpodSystem.ModuleUSB, selectedModuleName)
    BpodSystem.ModuleUSB = rmfield(BpodSystem.ModuleUSB, selectedModuleName);
end
SaveModuleUSBConfig;

function selectFromModuleList(junk, moreJunk)
global BpodSystem
selectedModule = get(BpodSystem.GUIHandles.ModuleList, 'Value');
set(BpodSystem.GUIHandles.PairedUSBList, 'Value', selectedModule);

function selectFromPairedList(junk, moreJunk)
global BpodSystem
selectedModule = get(BpodSystem.GUIHandles.PairedUSBList, 'Value');
set(BpodSystem.GUIHandles.ModuleList, 'Value', selectedModule);

function refreshFreeUSBPorts
global BpodSystem
USBPorts = BpodSystem.FindUSBSerialPorts;
USBPorts = USBPorts(logical(1-strcmp(USBPorts, BpodSystem.SerialPort.PortName)));
if ~isempty(BpodSystem.HW.AppSerialPortName)
    USBPorts = USBPorts(logical(1-strcmp(USBPorts, BpodSystem.HW.AppSerialPortName)));
end
if ~isempty(BpodSystem.AnalogSerialPort)
    USBPorts = USBPorts(logical(1-strcmp(USBPorts, BpodSystem.AnalogSerialPort.PortName)));
end
if ispc
    [Status RawString] = system('chgport'); % Extra step equired to find HARP Sound Card
    if ~strcmp(RawString(1:9), 'No serial')
        if ~isempty(strfind(RawString, '\Device\VCP'))
            Spaces = strfind(RawString, ' ');
            HARPCOMPort = RawString(1:Spaces(1)-1);
            USBPorts = [USBPorts {HARPCOMPort}];
        end
    end
end

for i = 1:length(BpodSystem.Modules.Name)
    USBPorts = USBPorts(logical(1-strcmp(USBPorts, BpodSystem.Modules.USBport{i})));
end
set(BpodSystem.GUIHandles.PairedUSBList, 'String', BpodSystem.Modules.USBport);
set(BpodSystem.GUIHandles.FreeUSBList, 'String', USBPorts);

function SaveModuleUSBConfig
global BpodSystem
load(BpodSystem.Path.ModuleUSBConfig);
for i = 1:BpodSystem.Modules.nModules
    ModuleUSBConfig.USBPorts{i} = BpodSystem.Modules.USBport{i};
    if ~isempty(ModuleUSBConfig.USBPorts{i})
        ModuleUSBConfig.ModuleNames{i} = BpodSystem.Modules.Name{i};
    else
        ModuleUSBConfig.ModuleNames{i} = [];
    end
end
save(BpodSystem.Path.ModuleUSBConfig, 'ModuleUSBConfig');