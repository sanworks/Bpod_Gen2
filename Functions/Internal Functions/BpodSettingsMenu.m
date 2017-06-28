%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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
BpodSystem.GUIHandles.SettingsMenuFig = figure('Position', [650 480 397 126],'name','Settings Menu','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom');
BG = imread('SettingsMenuBG2.bmp');
image(BG); axis off; drawnow;
text(100, 25,'Settings Menu', 'FontName', 'OCRAStd', 'FontSize', 13, 'Color', [0.8 0.8 0.8]);
ypos = 20;
LiquidCalButtonGFX = imread('WaterCalBW.bmp');
BpodSystem.GUIHandles.LiquidCalLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @CalibrateValves, 'CData', LiquidCalButtonGFX, 'TooltipString', 'Calibrate valves for precise liquid delivery');
SpeakerCalButtonGFX = imread('SpeakerCalButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SpeakerCalButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @CalibrateSound, 'CData', SpeakerCalButtonGFX, 'TooltipString', 'Calibrate auditory pure tone intensity');
BonsaiButtonGFX = imread('BonsaiButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SoundCalLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @ConfigureBonsai, 'CData', BonsaiButtonGFX, 'TooltipString', 'Setup Bonsai socket connection');
PortCalButtonGFX = imread('PortConfigButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.PortCalLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @ConfigurePorts, 'CData', PortCalButtonGFX, 'TooltipString', 'Configure low impedence inputs (ports and wire terminals)');
SyncButtonGFX = imread('SyncConfigButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SyncLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @ConfigureSync, 'CData', SyncButtonGFX, 'TooltipString', 'Configure state synchronization signal');
FolderButtonGFX = imread('FolderSetupButton.bmp'); ypos = ypos + 65;
BpodSystem.GUIHandles.SyncLaunchButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [ypos 32 40 40], 'Callback', @ConfigureFolders, 'CData', FolderButtonGFX, 'TooltipString', 'Select data and protocol root folders');

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

function ConfigureFolders(trash, othertrash)
global BpodSystem
close(BpodSystem.GUIHandles.SettingsMenuFig)
BpodSystem.setupFolders;