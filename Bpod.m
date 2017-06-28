%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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
function Bpod(varargin)
BpodLoaded = 0;
try
    evalin('base', 'BpodSystem;'); % BpodSystem is a global variable in the base workspace, representing the hardware
    BpodLoaded = 1;
catch
end
if BpodLoaded
    error('Bpod is already open. Please close the Bpod console and try again.');
end
warning off
global BpodSystem
BpodPath = fileparts(which('Bpod'));
addpath(genpath(fullfile(BpodPath, 'Functions')));
BpodSystem = BpodObject;
% Try to find hardware. If none, prompt to run emulation mode.
if nargin > 0
    if strcmp(varargin{1}, 'EMU')
        EmulatorDialog;
    else
        try
            if nargin > 1
                ForceJava = varargin{2};
                BpodSystem.InitializeHardware(varargin{1}, ForceJava);
            else
                BpodSystem.InitializeHardware(varargin{1});
            end
            BpodSetup;
        catch
            EmulatorDialog;
        end
    end
else
    try
        BpodSystem.InitializeHardware('AUTO');
        BpodSetup;
    catch
        EmulatorDialog;
    end
end

function BpodSetup
global BpodSystem
BpodSystem.Setup;
BpodSystem.InitializeGUI();
evalin('base', 'global BpodSystem')

function EmulatorSetup(hObject,event)
global BpodSystem
BpodSystem.EmulatorMode = 1;
BpodSystem.Setup;
BpodSystem.InitializeGUI();
evalin('base', 'global BpodSystem')

function EmulatorDialog
global BpodSystem
BpodErrorSound;
BpodSystem.GUIHandles.LaunchEmuFig = figure('Position',[500 350 300 125],'name','ERROR','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom'); BG = imread('DeviceNotFound.bmp'); image(BG); axis off;
BpodSystem.GUIData.CloseBpodButton = imread('CloseBpod.bmp');
BpodSystem.GUIData.LaunchEMUButton = imread('StartInEmuMode.bmp');
BpodSystem.GUIHandles.LaunchEmuModeButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [15 55 277 32], 'Callback', @EmulatorSetup, 'CData', BpodSystem.GUIData.LaunchEMUButton, 'TooltipString', 'Start Bpod in emulation mode');
BpodSystem.GUIHandles.CloseBpodButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [15 15 277 32], 'Callback', @CloseBpodHWNotFound, 'CData', BpodSystem.GUIData.CloseBpodButton,'TooltipString', 'Close Bpod');

function CloseBpodHWNotFound(hObject,event)
global BpodSystem
lasterr
close(BpodSystem.GUIHandles.LaunchEmuFig);
close(BpodSystem.GUIHandles.SplashFig);
delete(BpodSystem)
disp('Error: Bpod device not found.')