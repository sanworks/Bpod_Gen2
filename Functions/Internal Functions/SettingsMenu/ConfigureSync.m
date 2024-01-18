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

% ConfigureSync() launches a GUI to configure a Bpod output channel as a
% 'sync' channel to send TTL sync pulses to other instruments.

function ConfigureSync

global BpodSystem % Import the global BpodSystem object

if isfield(BpodSystem.GUIHandles, 'SyncConfigFig') && ~verLessThan('MATLAB', '8.4')
    if isgraphics(BpodSystem.GUIHandles.SyncConfigFig)
        figure(BpodSystem.GUIHandles.SyncConfigFig);
        return;
    end
end
if BpodSystem.MachineType == 1 % Bpod 0.5
    BpodErrorDlg(['Bpod 0.5 has a fixed sync' char(10) 'port. Config not required.'], 0);
else
    fontName = 'Courier New';
    BpodSystem.GUIHandles.SyncConfigFig = figure('Position',[600 400 400 150],'name','Sync config.',...
        'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
    ha = axes('units','normalized', 'position',[0 0 1 1]);
    uistack(ha,'bottom');
    BG = imread('InputChannelConfig2.bmp');
    image(BG); axis off;
    
    text(80, 25, 'Sync channel config', 'FontName', fontName, 'FontSize', 15, 'Color', [0.8 0.8 0.8]);
    text(50, 65, 'Channel', 'FontName', fontName, 'FontSize', 14, 'Color', [0.8 0.8 0.8]);
    text(210, 65, 'Signal type', 'FontName', fontName, 'FontSize', 14, 'Color', [0.8 0.8 0.8]);
    BpodSystem.GUIHandles.SyncConfigChannel = uicontrol('Position', [55 35 80 20], 'Style', 'popupmenu',... 
        'Callback', @update_sync_config, 'FontSize', 12);
    if BpodSystem.FirmwareVersion >= 23
        syncMenu = {'Each_Trial', 'Each_State', '10Hz_SqWave'};
    else
        syncMenu = {'Each_Trial', 'Each_State'};
    end
    BpodSystem.GUIHandles.SyncConfigType = uicontrol('Position', [220 35 120 20], 'Style', 'popupmenu',... 
        'String', syncMenu, 'Callback', @update_sync_config, 'FontSize', 12);
    
    % Populate menus
    digitalChannelStrings = cell(1,BpodSystem.HW.n.Outputs);
    digitalChannelStrings{1} = '-None-';
    nChan = 1;
    nPorts = 0; nBNC = 0; nWire = 0; nDigital = 0;
    for i = 1:BpodSystem.HW.n.Outputs
        thisChannelType = BpodSystem.HW.Outputs(i);
        switch thisChannelType
            case 'P'
                nPorts = nPorts + 1; nChan = nChan + 1;
                digitalChannelStrings{nChan} = ['Port' num2str(nPorts)];
            case 'B'
                nBNC = nBNC + 1; nChan = nChan + 1;
                digitalChannelStrings{nChan} = ['BNC' num2str(nBNC)];
            case 'W'
                nWire = nWire + 1; nChan = nChan + 1;
                digitalChannelStrings{nChan} = ['Wire' num2str(nWire)];
            case 'D'
                nDigital = nDigital + 1; nChan = nChan + 1;
                digitalChannelStrings{nChan} = ['Digital' num2str(nDigital)];
        end
    end
    digitalChannelStrings = digitalChannelStrings(1:nChan);
    if BpodSystem.SyncConfig.Channel == 255
        channelListboxValue = 1;
    else
        channelListboxValue = BpodSystem.SyncConfig.Channel-BpodSystem.HW.Pos.Output_BNC+3;
    end
    
    set(BpodSystem.GUIHandles.SyncConfigChannel, 'string',digitalChannelStrings);
    set(BpodSystem.GUIHandles.SyncConfigChannel, 'value', channelListboxValue);
    set(BpodSystem.GUIHandles.SyncConfigType, 'value', BpodSystem.SyncConfig.SignalType+1);
end

function update_sync_config(~,~)
global BpodSystem % Import the global BpodSystem object
ch = get(BpodSystem.GUIHandles.SyncConfigChannel, 'Value') - 1;
type = get(BpodSystem.GUIHandles.SyncConfigType, 'Value') - 1;
if ch > 0
    syncHWChannel = ch + BpodSystem.HW.Pos.Output_BNC - 2; % 2 to Convert BNC position to 0-index and convert SyncHWChannel to 0-index
else
    ch = 255;
    syncHWChannel = 255;
end
if ~BpodSystem.EmulatorMode
    BpodSystem.SerialPort.write(['K' syncHWChannel type], 'uint8');
    confirmed = BpodSystem.SerialPort.read(1, 'uint8');
    if confirmed ~= 1
        error('Failed to set sync parameters');
    end
end
BpodSystem.SyncConfig.Channel = syncHWChannel;
BpodSystem.SyncConfig.SignalType = type;
BpodSyncConfig = BpodSystem.SyncConfig;
save(BpodSystem.Path.SyncConfig, 'BpodSyncConfig');