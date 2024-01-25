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

% BpodObject.FindUSBSerialPorts() discovers available usb serial ports using system command line tools
% Returns: usbSerialPorts, a cell array of strings with available serial port names

function usbSerialPorts = FindUSBSerialPorts(obj)

usbSerialPorts = {}; % Initialize empty cell array

if exist('serialportlist','file')
    portLocations = sort(serialportlist('available'));
elseif exist('seriallist','file')
    portLocations = sort(seriallist('available'));
else % Likely MATLAB pre r2017a. Fall back to system call.
    % Get and split the system's list of available ports
    if ispc
        % For Windows: Use PowerShell command to list serial ports
        [~, RawString] = system('powershell.exe -inputformat none "[System.IO.Ports.SerialPort]::getportnames()"');
        portLocations = strsplit(RawString, {'\r\n', '\n', '\r'}); % Split the output by possible newline characters
    elseif ismac
        % For macOS: List USB serial devices
        [~, rawSerialPortList] = system('ls /dev/cu.usbmodem*');
        portLocations = strsplit(strtrim(rawSerialPortList), '\n');
    else
        % For Linux: List ACM serial devices
        [~, rawSerialPortList] = system('ls /dev/ttyACM*');
        portLocations = strsplit(strtrim(rawSerialPortList), {'  ', '\n'});
    end
end

% Filter and add ports to usbSerialPorts
for p = 1:length(portLocations)
    candidatePort = strtrim(portLocations{p}); % Trim whitespace
    if ~isempty(candidatePort) && (~ispc || ~strcmp(candidatePort, 'COM1')) % Exclude 'COM1' on Windows
        if ~any(strcmp(candidatePort, usbSerialPorts))
            usbSerialPorts{end+1} = candidatePort; % Add new port
        end
    end
end
