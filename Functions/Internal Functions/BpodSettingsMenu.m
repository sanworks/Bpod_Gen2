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
function BpodSettingsMenu

global BpodSystem

if isfield(BpodSystem.GUIHandles, 'SettingsMenuFig') && ~verLessThan('MATLAB', '8.4')
    if isgraphics(BpodSystem.GUIHandles.SettingsMenuFig)
        figure(BpodSystem.GUIHandles.SettingsMenuFig);
        return
    end
end


if ispc
    MenuWindowHeight = 126;
elseif ismac
    MenuWindowHeight = 126;
else
    MenuWindowHeight = 112;
end

if BpodSystem.MachineType == 4
    MenuWidth = 467;
    TitleXpos = 110;
else
    MenuWidth = 397;
    TitleXpos = 105;
end


BpodSystem.GUIHandles.SettingsMenuFig = figure('Position', [650 480 MenuWidth MenuWindowHeight],'name','Settings Menu','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('SettingsMenuBG2.bmp');
image(BG); axis off; drawnow;
text(TitleXpos, 25,'Settings Menu', 'FontName', 'Courier New', 'FontSize', 15, 'Color', [0.9 0.9 0.9]);
ypos = 20;
LiquidCalButtonGFX = imread('WaterCalBW.bmp');
BpodSystem.GUIHandles.LiquidCalLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @CalibrateValves, 'CData', LiquidCalButtonGFX, 'TooltipString', 'Calibrate valves for precise liquid delivery');
SpeakerCalButtonGFX = imread('SpeakerCalButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SpeakerCalButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @CalibrateSound, 'CData', SpeakerCalButtonGFX, 'TooltipString', 'Calibrate auditory pure tone intensity');
BonsaiButtonGFX = imread('BonsaiButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SoundCalLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @ConfigureBonsai, 'CData', BonsaiButtonGFX, 'TooltipString', 'Setup Bonsai socket connection');
PortCalButtonGFX = imread('PortConfigButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.PortCalLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @ConfigurePorts, 'CData', PortCalButtonGFX, 'TooltipString', 'Configure low impedence inputs (ports and wire terminals)');
if BpodSystem.MachineType == 4
    FlexConfigButtonGFX = imread('FlexConfigButton.bmp'); ypos = ypos + 65;
    BpodSystem.GUIHandles.FlexConfigLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @ConfigureFlex, 'CData', FlexConfigButtonGFX, 'TooltipString', 'Configure flex I/O channels');
end
SyncButtonGFX = imread('SyncConfigButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SyncLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @ConfigureBpodSync, 'CData', SyncButtonGFX, 'TooltipString', 'Configure state synchronization signal');
FolderButtonGFX = imread('FolderSetupButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.FolderLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @ConfigureFolders, 'CData', FolderButtonGFX, 'TooltipString', 'Select data and protocol root folders');

function CalibrateValves(trash, othertrash)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
BpodLiquidCalibration('Calibrate');

function CalibrateSound(trash, othertrash)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
SoundCalibrationManager;

function ConfigureBonsai(trash, othertrash)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
ConfigureBonsaiSocket;

function ConfigurePorts(trash, othertrash)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
BpodPortConfig;

function ConfigureFlex(trash, othertrash)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
FlexIOConfigGUI;

function ConfigureBpodSync(trash, othertrash)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
ConfigureSync;

function ConfigureFolders(trash, othertrash)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
BpodSystem.setupFolders;