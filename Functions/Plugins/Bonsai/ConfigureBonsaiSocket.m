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
function ConfigureBonsaiSocket
global BpodSystem
if isfield(BpodSystem.GUIHandles, 'ConfigureBonsaiFig') && ~verLessThan('MATLAB', '8.4')
    if isgraphics(BpodSystem.GUIHandles.ConfigureBonsaiFig)
        figure(BpodSystem.GUIHandles.ConfigureBonsaiFig);
        return;
    end
end
BpodSystem.GUIHandles.ConfigureBonsaiFig = figure('Position', [350 380 300 300],'name','Bonsai socket configuration','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('BonsaiSettingsBG.bmp');
image(BG); axis off; drawnow;
BpodSystem.GUIHandles.BonsaiConnectButtonGFX = imread('BonsaiConnectButton.bmp');
BpodSystem.GUIHandles.BonsaiDisconnectButtonGFX = imread('BonsaiDisconnectButton.bmp');
BpodSystem.GUIHandles.BonsaiConnectButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [75 65 150 40], 'Callback', @ConnectToBonsai, 'CData', BpodSystem.GUIHandles.BonsaiConnectButtonGFX, 'TooltipString', 'Connect to Bonsai');
BpodSystem.GUIHandles.BonsaiConnectStatus = uicontrol('Style', 'text', 'String', 'Disconnected', 'Position', [75 228 150 30], 'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', 'r', 'BackgroundColor', [.6 .6 .6]);
BpodSystem.GUIHandles.BonsaiIPEdit = uicontrol('Style', 'edit', 'String', 'localhost', 'Position', [75 155 150 30], 'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', 'k', 'BackgroundColor', [.9 .9 .9]);
BpodSystem.GUIHandles.BonsaiPortEdit = uicontrol('Style', 'edit', 'String', '11235', 'Position', [75 115 150 30], 'FontSize', 14, 'FontWeight', 'bold', 'ForegroundColor', 'k', 'BackgroundColor', [.9 .9 .9]);
BpodSystem.GUIHandles.BonsaiAutoConnectSelector = uicontrol('Style', 'checkbox', 'String', '', 'Position', [255 28 15 15], 'BackgroundColor', [.9 .9 .9], 'Callback', @SetBonsaiAutoConnect, 'Enable', 'off');
if isfield(BpodSystem.SystemSettings, 'BonsaiAutoConnect')
    set(BpodSystem.GUIHandles.BonsaiAutoConnectSelector, 'value', BpodSystem.SystemSettings.BonsaiAutoConnect);
end
if ~isempty(BpodSystem.BonsaiSocket)
    set(BpodSystem.GUIHandles.BonsaiConnectStatus, 'String', 'Connected', 'ForegroundColor', 'g');
    set(BpodSystem.GUIHandles.BonsaiConnectButton, 'CData', BpodSystem.GUIHandles.BonsaiDisconnectButtonGFX);
end

function SetBonsaiAutoConnect(junk, otherjunk)
global BpodSystem
BonsaiAutoConnectStatus = get(BpodSystem.GUIHandles.BonsaiAutoConnectSelector, 'value');
BpodSystem.SystemSettings.BonsaiAutoConnect = BonsaiAutoConnectStatus;

function ConnectToBonsai(junk, otherjunk)
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