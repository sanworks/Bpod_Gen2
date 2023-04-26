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
function obj = Connect2BpodSM(obj, portString, varargin)
    if ~ispc && ~ismac
        % Warn user if Linux udev rules file is not in place
        if ~exist('/etc/udev/rules.d/00-teensy.rules')
            warning(['Linux udev rules file not found. Bpod devices newer than state machine r1 may not function.' char(10) 'Follow instructions <a href="matlab:web(''https://www.pjrc.com/teensy/00-teensy.rules'',''-browser'')">here</a>'])
        end
    end
    AutoMode = strcmp(portString, 'AUTO');
    SkipDiscovery = 0;
    if AutoMode
        Ports = obj.FindUSBSerialPorts;
    else
        Ports = {portString}; SkipDiscovery = 1;
    end
    nPorts = length(Ports);
    PortsTried = [];
    Found = 0;
    iPort = 1;
    if nargin > 2
        ForceJava = 1;
    else
        ForceJava = 0;
    end
    while (Found == 0) && (iPort <= nPorts)
        ThisPort = Ports{iPort};
        PortsTried = [PortsTried ThisPort ' '];
        Connected = 0;
        if ForceJava
            try
                obj.SerialPort = ArCOMObject_Bpod(ThisPort, 12000000, 'Java');
                Connected = 1;
            catch
            end
        else
            try
                obj.SerialPort = ArCOMObject_Bpod(ThisPort, 12000000);
                Connected = 1;
            catch
            end
        end
        if Connected
            if SkipDiscovery
                obj.SerialPort.write('XZ6', 'uint8');
                pause(.5)
                if obj.SerialPort.bytesAvailable > 0
                    Trash = obj.SerialPort.read(obj.SerialPort.bytesAvailable, 'uint8');
                end
                obj.SerialPort.write('6', 'uint8');
                Reply = obj.SerialPort.read(1, 'uint8');
                if (Reply == '5') % If the Bpod state machine replied correctly
                    Found = 1;
                    thisPortIndex = iPort;
                    obj.Status.SerialPortName = ThisPort;
                end
            else
                pause(0.5) % Wait for Bpod's discovery byte
                if obj.SerialPort.bytesAvailable > 0
                    Message = obj.SerialPort.read(1, 'uint8');
                    if Message == 222 % If Bpod's discovery byte appeared in the buffer
                        obj.SerialPort.write('6', 'uint8'); % Cmd for handshake + stop sending discovery byte
                        pause(.5) % Wait for Bpod to stop sending discovery bytes
                        obj.SerialPort.flush; % Clear buffer
                        obj.SerialPort.write('6', 'uint8'); % Re-request handshake
                        Reply = obj.SerialPort.read(1, 'uint8');
                        if (Reply == '5') % If the Bpod state machine replied correctly
                            Found = 1;
                            thisPortIndex = iPort;
                            obj.Status.SerialPortName = ThisPort;
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
    if Found
        obj.EmulatorMode = 0;
    else
        if sum(PortsTried) > 0
            AutoModeMessage = [];
            if AutoMode
                AutoModeMessage = ['Try calling Bpod with a serial port argument, i.e. Bpod(''' Ports{1} ''')'];
            end
            error([char(10) 'Error: Could not find Bpod State Machine.' char(10)...
                'Tried USB serial port(s): ' PortsTried char(10)...
                AutoModeMessage]);
        else
            error('Error: Could not find Bpod State Machine.')
        end
    end
    if obj.SerialPort.UsePsychToolbox == 0 && verLessThan('matlab', '9.7')
        disp('###########################################################################')
        disp('# NOTICE: Bpod is running without Psychtoolbox installed.                 #')
        disp('# PsychToolbox integration greatly improves USB transfer speed + latency. #')
        disp('# See http://psychtoolbox.org/download.html for installation instructions.#')
        disp('###########################################################################')
    end
    obj.SystemSettings.LastCOMPort = Ports{thisPortIndex};
    obj.SaveSettings;
    obj.EmulatorMode = 0;
    obj.BpodSplashScreen(2);
end