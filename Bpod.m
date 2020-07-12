%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2018 Sanworks LLC, Stony Brook, New York, USA

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
%system('wmic process where name="MATLAB.exe" CALL setpriority "high priority" > NUL');
BpodLoaded = 0;
try
    evalin('base', 'BpodSystem;'); % BpodSystem is a global variable in the base workspace, representing the hardware
    isEmpty = evalin('base', 'isempty(BpodSystem);');
    if isEmpty
        evalin('base', 'clear global BpodSystem;')
    else
        BpodLoaded = 1;
    end
catch
end
if BpodLoaded
    error('Bpod is already open. Please close the Bpod console and try again.');
end
warning off
global BpodSystem
BpodPath = fileparts(which('Bpod'));
addpath(genpath(fullfile(BpodPath, 'Functions')));

% adding a third argument to show the GUI: 1 = show GUI (default), 0 = don't show GUI
if nargin > 2
    BpodSystem = BpodObject(varargin{3});
else
    BpodSystem = BpodObject;
end

Ver = BpodSoftwareVersion;
disp(['Starting Bpod Console v' sprintf('%3.2f', Ver)])

% Try to find hardware. If none, prompt to run emulation mode.
if nargin > 0
    if strcmp(varargin{1}, 'EMU')
        EmulatorDialog;
    else
        %try
            if nargin > 1
                ForceJava = varargin{2};
                BpodSystem.Connect2BpodSM(varargin{1}, ForceJava);
            else
                BpodSystem.Connect2BpodSM(varargin{1});
            end
            BpodSetup;
        %catch
        %    EmulatorDialog;
        %end
    end
else
    try
        BpodSystem.Connect2BpodSM('AUTO');
        BpodSetup;
    catch
        if isfield(BpodSystem.GUIData, 'OldFirmwareFlag')
            close(BpodSystem.GUIHandles.SplashFig);
            delete(BpodSystem)
        else
            EmulatorDialog;
        end
    end
end

function BpodSetup
global BpodSystem
BpodSystem.SetupHardware;
if BpodSystem.ShowGUI % check show gui flag
    BpodSystem.InitializeGUI();
end
evalin('base', 'global BpodSystem')

function EmulatorSetup(hObject,event)
global BpodSystem
BpodSystem.EmulatorMode = 1;
BpodSystem.SetupHardware;
if BpodSystem.ShowGUI % check show gui flag
    BpodSystem.InitializeGUI();
end
evalin('base', 'global BpodSystem')

function EmulatorDialog
global BpodSystem
BpodSystem.GUIHandles.LaunchEmuFig = figure('Position',[500 350 300 125],'name','ERROR','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
if ~BpodSystem.ShowGUI %check show gui flag -- if not, just run the emulator without prompting
    set(BpodSystem.GUIHandles.LaunchEmuFig, 'visible', 'off')
    EmulatorSetup;
else
    BpodErrorSound;
    ha = axes('units','normalized', 'position',[0 0 1 1]);
    uistack(ha,'bottom'); BG = imread('DeviceNotFound.bmp'); image(BG); axis off;
    BpodSystem.GUIData.CloseBpodButton = imread('CloseBpod.bmp');
    BpodSystem.GUIData.LaunchEMUButton = imread('StartInEmuMode.bmp');
    BpodSystem.GUIHandles.LaunchEmuModeButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [15 55 277 32], 'Callback', @EmulatorSetup, 'CData', BpodSystem.GUIData.LaunchEMUButton, 'TooltipString', 'Start Bpod in emulation mode');
    BpodSystem.GUIHandles.CloseBpodButton = uicontrol('Style', 'pushbutton', 'String', '', 'Position', [15 15 277 32], 'Callback', @CloseBpodHWNotFound, 'CData', BpodSystem.GUIData.CloseBpodButton,'TooltipString', 'Close Bpod');
end

function CloseBpodHWNotFound(hObject,event)
global BpodSystem
lasterr
close(BpodSystem.GUIHandles.LaunchEmuFig);
close(BpodSystem.GUIHandles.SplashFig);
delete(BpodSystem)
disp('Error: Bpod device not found.')