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

% BpodObject.Connect2BpodSM() finds and connects to the Bpod state machine.
% It is called by Bpod.m as part of the system startup routine.
%
% Arguments:
% portString: the name of the USB serial port as known to the operating system.
%             On Windows this looks like 'COM3' and on Linux '/dev/ttyACM0'
%             use 'AUTO' to auto-discover the Bpod State Machine's port
% forceJava:  (optional, char array) if supplied, Bpod uses MATLAB's native
%             serial interface instead of PsychToolbox IOPort if installed

function obj = Connect2BpodSM(obj, portString, varargin)

% On Linux, warn user if Linux udev rules file is not in place
if ~ispc && ~ismac
    if ~exist('/etc/udev/rules.d/00-teensy.rules')
        warning(['Linux udev rules file not found. Bpod devices newer than state machine r1 may not function.' char(10)...
            'Follow instructions <a href="matlab:web(''https://www.pjrc.com/teensy/00-teensy.rules'',''-browser'')">here</a>']) %#ok
    end
end

% Determine list of ports to try
autoMode = strcmp(portString, 'AUTO');
skipDiscovery = 0;
if autoMode
    Ports = obj.FindUSBSerialPorts;
else
    Ports = {portString}; skipDiscovery = 1;
end

% Attempt to connect to each port in the list
nPorts = length(Ports);
portsTried = [];
found = 0;
iPort = 1;
if nargin > 2
    forceJava = 1;
else
    forceJava = 0;
end
while (found == 0) && (iPort <= nPorts)
    thisPort = Ports{iPort};
    portsTried = [portsTried thisPort ' '];
    connected = 0;
    if forceJava
        try
            obj.SerialPort = ArCOMObject_Bpod(thisPort, 12000000, 'Java');
            connected = 1;
        catch
        end
    else
        try
            obj.SerialPort = ArCOMObject_Bpod(thisPort, 12000000);
            connected = 1;
        catch
        end
    end
    if connected
        if skipDiscovery
            obj.SerialPort.write('XZ6', 'uint8');
            pause(.5)
            if obj.SerialPort.bytesAvailable > 0
                Trash = obj.SerialPort.read(obj.SerialPort.bytesAvailable, 'uint8');
            end
            obj.SerialPort.write('6', 'uint8');
            reply = obj.SerialPort.read(1, 'uint8');
            if (reply == '5') % If the Bpod state machine replied correctly
                found = 1;
                thisPortIndex = iPort;
                obj.Status.SerialPortName = thisPort;
            end
        else
            pause(0.5) % Wait for Bpod's discovery byte
            if obj.SerialPort.bytesAvailable > 0
                message = obj.SerialPort.read(1, 'uint8');
                if message == 222 % If Bpod's discovery byte appeared in the buffer
                    obj.SerialPort.write('6', 'uint8'); % Cmd for handshake + stop sending discovery byte
                    pause(.5) % Wait for Bpod to stop sending discovery bytes
                    obj.SerialPort.flush; % Clear buffer
                    obj.SerialPort.write('6', 'uint8'); % Re-request handshake
                    reply = obj.SerialPort.read(1, 'uint8');
                    if (reply == '5') % If the Bpod state machine replied correctly
                        found = 1;
                        thisPortIndex = iPort;
                        obj.Status.SerialPortName = thisPort;
                    end
                else
                    obj.SerialPort.delete;
                end
            else
                obj.SerialPort.delete;
            end
        end
    end
    iPort = iPort + 1;
end

% If a port was not found, return an error
if found
    obj.EmulatorMode = 0;
else
    if sum(portsTried) > 0
        autoModeMessage = [];
        if autoMode
            autoModeMessage = ['Try calling Bpod with a serial port argument, i.e. Bpod(''' Ports{1} ''')'];
        end
        error([char(10) 'Error: Could not find Bpod State Machine.' char(10)...
            'Tried USB serial port(s): ' portsTried char(10)...
            autoModeMessage]);
    else
        error('Error: Could not find Bpod State Machine.')
    end
end

% For MATLAB predating the builtin serialport() class (2019b), recommend PsychToolbox
if obj.SerialPort.UsePsychToolbox == 0 && verLessThan('matlab', '9.7')
    disp('###########################################################################')
    disp('# NOTICE: Bpod is running without Psychtoolbox installed.                 #')
    disp('# PsychToolbox integration greatly improves USB transfer speed + latency. #')
    disp('# See http://psychtoolbox.org/download.html for installation instructions.#')
    disp('###########################################################################')
end

% Finish setup
obj.SystemSettings.LastCOMPort = Ports{thisPortIndex};
obj.SaveSettings;
obj.EmulatorMode = 0;
obj.BpodSplashScreen(2);
end