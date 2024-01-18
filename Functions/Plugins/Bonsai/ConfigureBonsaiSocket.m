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

% ConfigureBonsaiSocket() is a legacy GUI tool to set up a connection to Bonsai software.
% This tool sets up a local TCP/IP socket, which Bonsai can connect to.
% Bytes are relayed between Bonsai and the Bpod State Machine during trials.
%
% *NOTE* With Firmware v23, state machine r2.0 and newer have a secondary
%        USB serial port (the "app" port), which can directly attach to Bonsai.
%        See \Bpod_Gen2\Functions\Plugins\Bonsai\APP_SoftCode Example\ for usage.

function ConfigureBonsaiSocket

global BpodSystem % Import the global BpodSystem object

if isfield(BpodSystem.GUIHandles, 'ConfigureBonsaiFig') && ~verLessThan('MATLAB', '8.4')
    if isgraphics(BpodSystem.GUIHandles.ConfigureBonsaiFig)
        figure(BpodSystem.GUIHandles.ConfigureBonsaiFig);
        return;
    end
end
BpodSystem.GUIHandles.ConfigureBonsaiFig = figure('Position', [350 380 300 300],'name',...
    'Bonsai socket configuration','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('BonsaiSettingsBG.bmp');
image(BG); axis off; drawnow;
BpodSystem.GUIHandles.BonsaiConnectButtonGFX = imread('BonsaiConnectButton.bmp');
BpodSystem.GUIHandles.BonsaiDisconnectButtonGFX = imread('BonsaiDisconnectButton.bmp');
BpodSystem.GUIHandles.BonsaiConnectButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position',... 
    [75 65 150 40], 'Callback', @connect2bonsai, 'CData', BpodSystem.GUIHandles.BonsaiConnectButtonGFX,... 
    'TooltipString', 'Connect to Bonsai');
BpodSystem.GUIHandles.BonsaiConnectStatus = uicontrol('Style', 'text', 'String', 'Disconnected', 'Position',... 
    [75 228 150 30], 'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', 'r', 'BackgroundColor', [.6 .6 .6]);
BpodSystem.GUIHandles.BonsaiIPEdit = uicontrol('Style', 'edit', 'String', 'localhost', 'Position', [75 155 150 30],... 
    'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', 'k', 'BackgroundColor', [.9 .9 .9]);
BpodSystem.GUIHandles.BonsaiPortEdit = uicontrol('Style', 'edit', 'String', '11235', 'Position', [75 115 150 30],... 
    'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', 'k', 'BackgroundColor', [.9 .9 .9]);
BpodSystem.GUIHandles.BonsaiAutoConnectSelector = uicontrol('Style', 'checkbox', 'String', '', 'Position',... 
    [255 28 15 15], 'BackgroundColor', [.9 .9 .9], 'Callback', @set_bonsai_autoconnect, 'Enable', 'off');
if isfield(BpodSystem.SystemSettings, 'BonsaiAutoConnect')
    set(BpodSystem.GUIHandles.BonsaiAutoConnectSelector, 'value', BpodSystem.SystemSettings.BonsaiAutoConnect);
end
if ~isempty(BpodSystem.BonsaiSocket)
    set(BpodSystem.GUIHandles.BonsaiConnectStatus, 'String', 'Connected', 'ForegroundColor', 'g');
    set(BpodSystem.GUIHandles.BonsaiConnectButton, 'CData', BpodSystem.GUIHandles.BonsaiDisconnectButtonGFX);
end

function set_bonsai_autoconnect(a, b)
global BpodSystem
bonsaiAutoConnectStatus = get(BpodSystem.GUIHandles.BonsaiAutoConnectSelector, 'value');
BpodSystem.SystemSettings.BonsaiAutoConnect = bonsaiAutoConnectStatus;

function connect2bonsai(a, b)
global BpodSystem
if isempty(BpodSystem.BonsaiSocket)
    set(BpodSystem.GUIHandles.BonsaiConnectStatus, 'String', 'Connecting', 'ForegroundColor', 'y'); drawnow;
    try
        BpodSystem.BonsaiSocket = TCPCom(11235);
    catch
        set(BpodSystem.GUIHandles.BonsaiConnectStatus, 'String', 'Disconnected', 'ForegroundColor', 'r');
        rethrow(lasterror);
    end
    set(BpodSystem.GUIHandles.BonsaiConnectStatus, 'String', 'Connected', 'ForegroundColor', 'g');
    set(BpodSystem.GUIHandles.BonsaiConnectButton, 'CData', BpodSystem.GUIHandles.BonsaiDisconnectButtonGFX);
 else
     BpodSystem.BonsaiSocket = [];
     set(BpodSystem.GUIHandles.BonsaiConnectStatus, 'String', 'Disconnected', 'ForegroundColor', 'r');
     set(BpodSystem.GUIHandles.BonsaiConnectButton, 'CData', BpodSystem.GUIHandles.BonsaiConnectButtonGFX);
end