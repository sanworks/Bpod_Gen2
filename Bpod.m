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

% Bpod() is the entry point for using the Bpod behavior measurement system.
% It connects to the Bpod State Machine and launches the Console GUI.
% It also creates the global BpodSystem object in the base workspace.
%
% Arguments (optional)
% SerialPort: The state machine's USB serial port name. By default, the
% port name is automatically detected. This argument skips auto-detection. 
% It is necessary to connect separate instances of MATLAB to separate machines.
% Note: To launch directly into emulator mode, use port name EMU.
%
% Java: On MATLAB pre-r2019a, adding a second argument 'Java' forces usage 
% of MATLAB's legacy Java serial interface, even with PsychToolbox installed.
%
% Example usage
% Bpod();       % Start Bpod and auto-detect the state machine serial port
% Bpod('COM3'); % Start Bpod with a state machine on port COM3
% Bpod('EMU');  % Start Bpod state machine emulator

function Bpod(varargin)

global BpodSystem

% Ensure that Bpod is not open, and clear partially initialized instances.
isInitialized = false;
if ~isempty(BpodSystem)
    if isprop(BpodSystem, 'Status') && isprop(BpodSystem, 'GUIHandles')
        if BpodSystem.Status.Initialized && isgraphics(BpodSystem.GUIHandles.MainFig)
            isInitialized = true;
        end
    end
end
if isInitialized
    error('Bpod is already open. Please close the Bpod console and try again.');
else
    if isprop(BpodSystem, 'SerialPort')
        EndBpod; % Hardware was initialized. EndBpod() disconnects gracefully.
        Bpod; % EndBpod() clears the global. Bpod must be called to reinitialize it.
        return
    else
        if ~isempty(BpodSystem)
        warning(['A partially initialized BpodSystem variable was cleared.' char(10)...
                 'This may happen if a previous startup attempt crashed, or if user' char(10)... 
                 'startup code created a global BpodSystem variable before calling Bpod()'])
        end
        BpodSystem = []; % Clear partially initialized object
    end
end

% Setup path
bpodPath = fileparts(which('Bpod'));
addpath(genpath(fullfile(bpodPath, 'Functions')));

% Initialize BpodSystem. The BpodSystem class is used for system config.
BpodSystem = BpodObject;

% Try to find hardware. If none, prompt to run emulation mode.
if nargin > 0
    if strcmp(varargin{1}, 'EMU')
        emulator_setup;
    else
        if nargin > 1
            forceJava = varargin{2};
            BpodSystem.Connect2BpodSM(varargin{1}, forceJava);
        else
            BpodSystem.Connect2BpodSM(varargin{1});
        end
        bpod_setup;
    end
else
    try
        BpodSystem.Connect2BpodSM('AUTO');
        bpod_setup;
    catch ME
        BpodSystem.GUIData.LaunchError = ME;
        if isfield(BpodSystem.GUIData, 'FutureFirmwareFlag')
            close(BpodSystem.GUIHandles.SplashFig);
            clear global BpodSystem
            rethrow(ME)
        else
            emulator_dialog;
        end
    end
end

function emulator_setup(varargin)
% Runs setup with emulator mode flag set to 'true'.
% Two optional arguments are automatically passed when called from the GUI.
% These args are ignored.
global BpodSystem
BpodSystem.EmulatorMode = true;
bpod_setup;

function bpod_setup
% Runs BpodSystem's hardware and GUI setup methods.
global BpodSystem
BpodSystem.SetupHardware();
BpodSystem.InitializeGUI();
BpodSystem.Status.Initialized = true;
evalin('base', 'global BpodSystem')

function emulator_dialog
% Launches a GUI indicating that hardware connection has failed.
% Prompts the user to start emulator mode or close the program.
global BpodSystem
BpodErrorSound;
BpodSystem.GUIHandles.LaunchEmuFig = figure('Position',[500 350 300 125],...
    'name','ERROR','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
ha = axes('units','normalized', 'position',[0 0 1 1]);
uistack(ha,'bottom'); BG = imread('DeviceNotFound.bmp'); image(BG); axis off;
BpodSystem.GUIData.CloseBpodButton = imread('CloseBpod.bmp');
BpodSystem.GUIData.LaunchEMUButton = imread('StartInEmuMode.bmp');
BpodSystem.GUIHandles.LaunchEmuModeButton = uicontrol('Style', 'pushbutton',... 
    'String', '', 'Position', [15 55 277 32], 'Callback', @emulator_setup,... 
    'CData', BpodSystem.GUIData.LaunchEMUButton, 'TooltipString',... 
    'Start Bpod in emulation mode');
BpodSystem.GUIHandles.CloseBpodButton = uicontrol('Style', 'pushbutton',... 
    'String', '', 'Position', [15 15 277 32], 'Callback', @close_bpod,... 
    'CData', BpodSystem.GUIData.CloseBpodButton,'TooltipString', 'Close Bpod');

function close_bpod(varargin)
% Closes the program when prompted by the user from the emulatorDialog GUI.
% Two optional arguments are automatically passed when called from the GUI.
% These args are ignored.
global BpodSystem
close(BpodSystem.GUIHandles.LaunchEmuFig);
close(BpodSystem.GUIHandles.SplashFig);
disp('Error: Bpod State Machine not found.')
guiData = BpodSystem.GUIData;
clear global BpodSystem
if isfield(guiData, 'LaunchError')
    rethrow(guiData.LaunchError)
else
    lasterr
end