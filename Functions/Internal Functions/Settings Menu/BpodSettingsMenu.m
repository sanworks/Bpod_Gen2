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

% BpodSettingsMenu() launches a settings menu GUI from a button on the Bpod console

function BpodSettingsMenu

global BpodSystem % Import the global BpodSystem object

if isfield(BpodSystem.GUIHandles, 'SettingsMenuFig') && ~verLessThan('MATLAB', '8.4')
    if isgraphics(BpodSystem.GUIHandles.SettingsMenuFig)
        figure(BpodSystem.GUIHandles.SettingsMenuFig);
        return
    end
end
if ispc
    menuWindowHeight = 126;
elseif ismac
    menuWindowHeight = 126;
else
    menuWindowHeight = 112;
end
if BpodSystem.MachineType == 4
    menuWidth = 467;
    titleXpos = 110;
else
    menuWidth = 397;
    titleXpos = 105;
end
BpodSystem.GUIHandles.SettingsMenuFig = figure('Position', [650 480 menuWidth menuWindowHeight],'name',...
    'Settings Menu','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('SettingsMenuBG2.bmp');
image(BG); axis off; drawnow;
text(titleXpos, 25,'Settings Menu', 'FontName', 'Courier New', 'FontSize', 15, 'Color', [0.9 0.9 0.9]);
ypos = 20;
liquidCalButtonGFX = imread('WaterCalBW.bmp');
BpodSystem.GUIHandles.LiquidCalLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40],... 
    'Callback', @calibrate_valves, 'CData', liquidCalButtonGFX, 'TooltipString', 'Calibrate valves for precise liquid delivery');
speakerCalButtonGFX = imread('SpeakerCalButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SpeakerCalButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40],... 
    'Callback', @calibrate_sound, 'CData', speakerCalButtonGFX, 'TooltipString', 'Calibrate auditory pure tone intensity');
bonsaiButtonGFX = imread('BonsaiButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SoundCalLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40],... 
    'Callback', @configure_bonsai, 'CData', bonsaiButtonGFX, 'TooltipString', 'Setup Bonsai socket connection');
portCalButtonGFX = imread('PortConfigButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.PortCalLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40],... 
    'Callback', @configure_ports, 'CData', portCalButtonGFX, 'TooltipString', 'Configure low impedence inputs (ports and wire terminals)');
if BpodSystem.MachineType == 4
    flexConfigButtonGFX = imread('FlexConfigButton.bmp'); ypos = ypos + 65;
    BpodSystem.GUIHandles.FlexConfigLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40],... 
        'Callback', @configure_flexio, 'CData', flexConfigButtonGFX, 'TooltipString', 'Configure flex I/O channels');
end
syncButtonGFX = imread('SyncConfigButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SyncLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40],... 
    'Callback', @configure_sync, 'CData', syncButtonGFX, 'TooltipString', 'Configure state synchronization signal');
folderButtonGFX = imread('FolderSetupButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.FolderLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40],... 
    'Callback', @configure_folders, 'CData', folderButtonGFX, 'TooltipString', 'Select data and protocol root folders');

function calibrate_valves(~,~)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
BpodLiquidCalibration('Calibrate');

function calibrate_sound(~,~)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
SoundCalibrationManager;

function configure_bonsai(~,~)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
ConfigureBonsaiSocket;

function configure_ports(~,~)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
BpodPortConfig;

function configure_flexio(~,~)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
FlexIOConfigGUI;

function configure_sync(~,~)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
ConfigureSync;

function configure_folders(~,~)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
BpodSystem.setupFolders;