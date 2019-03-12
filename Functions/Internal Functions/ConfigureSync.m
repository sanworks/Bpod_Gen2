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
function ConfigureSync(junk, morejunk)
global BpodSystem
if BpodSystem.MachineType == 1 % Bpod 0.5
    BpodErrorDlg(['Bpod 0.5 has a fixed sync' char(10) 'port. Config not required.'], 0);
else
    FontName = 'Courier New';
    BpodSystem.GUIHandles.PortConfigFig = figure('Position',[600 400 400 150],'name','Sync config.','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
    ha = axes('units','normalized', 'position',[0 0 1 1]);
    uistack(ha,'bottom');
    BG = imread('InputChannelConfig2.bmp');
    image(BG); axis off;
    
    text(80, 25, 'Sync channel config', 'FontName', FontName, 'FontSize', 15, 'Color', [0.8 0.8 0.8]);
    text(50, 65, 'Channel', 'FontName', FontName, 'FontSize', 14, 'Color', [0.8 0.8 0.8]);
    text(210, 65, 'Signal type', 'FontName', FontName, 'FontSize', 14, 'Color', [0.8 0.8 0.8]);
    BpodSystem.GUIHandles.SyncConfigChannel = uicontrol('Position', [55 35 80 20], 'Style', 'popupmenu', 'Callback', @UpdateSyncConfig, 'FontSize', 12);
    BpodSystem.GUIHandles.SyncConfigType = uicontrol('Position', [220 35 120 20], 'Style', 'popupmenu', 'String', {'Each_Trial', 'Each_State'}, 'Callback', @UpdateSyncConfig, 'FontSize', 12);
    
    % Populate menus
    DigitalChannelStrings = cell(1,BpodSystem.HW.n.Outputs);
    DigitalChannelStrings{1} = '-None-';
    nChan = 1;
    nPorts = 0; nBNC = 0; nWire = 0; nDigital = 0;
    for i = 1:BpodSystem.HW.n.Outputs
        ThisChannelType = BpodSystem.HW.Outputs(i);
        switch ThisChannelType
            case 'P'
                nPorts = nPorts + 1; nChan = nChan + 1;
                DigitalChannelStrings{nChan} = ['Port' num2str(nPorts)];
            case 'B'
                nBNC = nBNC + 1; nChan = nChan + 1;
                DigitalChannelStrings{nChan} = ['BNC' num2str(nBNC)];
            case 'W'
                nWire = nWire + 1; nChan = nChan + 1;
                DigitalChannelStrings{nChan} = ['Wire' num2str(nWire)];
            case 'D'
                nDigital = nDigital + 1; nChan = nChan + 1;
                DigitalChannelStrings{nChan} = ['Digital' num2str(nDigital)];
        end
    end
    DigitalChannelStrings = DigitalChannelStrings(1:nChan);
    if BpodSystem.SyncConfig.Channel == 255
        ChannelListboxValue = 1;
    else
        ChannelListboxValue = BpodSystem.SyncConfig.Channel-BpodSystem.HW.Pos.Output_BNC+3;
    end
    
    set(BpodSystem.GUIHandles.SyncConfigChannel, 'string',DigitalChannelStrings);
    set(BpodSystem.GUIHandles.SyncConfigChannel, 'value', ChannelListboxValue);
    set(BpodSystem.GUIHandles.SyncConfigType, 'value', BpodSystem.SyncConfig.SignalType+1);
end

function UpdateSyncConfig(hObject,event)
global BpodSystem
Ch = get(BpodSystem.GUIHandles.SyncConfigChannel, 'Value') - 1;
Type = get(BpodSystem.GUIHandles.SyncConfigType, 'Value') - 1;
if Ch > 0
    SyncHWChannel = Ch + BpodSystem.HW.Pos.Output_BNC - 2; % 2 to Convert BNC position to 0-index and convert SyncHWChannel to 0-index
else
    Ch = 255;
    SyncHWChannel = 255;
end
if ~BpodSystem.EmulatorMode
    BpodSystem.SerialPort.write(['K' SyncHWChannel Type], 'uint8');
    Confirmed = BpodSystem.SerialPort.read(1, 'uint8');
    if Confirmed ~= 1
        error('Failed to set sync parameters');
    end
end
BpodSystem.SyncConfig.Channel = SyncHWChannel;
BpodSystem.SyncConfig.SignalType = Type;
BpodSyncConfig = BpodSystem.SyncConfig;
save (BpodSystem.Path.SyncConfig, 'BpodSyncConfig');