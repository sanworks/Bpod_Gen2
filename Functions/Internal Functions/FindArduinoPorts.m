%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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
function ArduinoPorts = FindArduinoPorts

if ispc
    [Status RawString] = system('wmic path Win32_SerialPort Where "Caption LIKE ''%Arduino%''" Get DeviceID'); % Search for Arduino on USB Serial
    PortLocations = strfind(RawString, 'COM');
    ArduinoPorts = cell(1,100);
    nPorts = length(PortLocations);
    for x = 1:nPorts
        Clip = RawString(PortLocations(x):PortLocations(x)+6);
        ArduinoPorts{x} = Clip(1:find(Clip == 32,1, 'first')-1);
    end
    ArduinoPorts = ArduinoPorts(1:nPorts);
 elseif ismac % Contributed by Thiago Gouvea JUN_9_2016
    [trash, RawSerialPortList] = system('ls /dev/tty.usbmodem*');
    string = strtrim(RawSerialPortList);
    PortStringPositions = strfind(string, '/dev/tty.usbmodem');
    nPorts = length(PortStringPositions);
    CandidatePorts = cell(1,nPorts);
    nGoodPorts = 0;
    for x = 1:nPorts
        if PortStringPositions(x)+20 <= length(string)
            CandidatePort = strtrim(string(PortStringPositions(x):PortStringPositions(x)+20));
            nGoodPorts = nGoodPorts + 1;
            CandidatePorts{nGoodPorts} = CandidatePort;
        end
    end
    ArduinoPorts = CandidatePorts(1:nGoodPorts);
else
    [trash, RawSerialPortList] = system('ls /dev/ttyACM*');
    string = strtrim(RawSerialPortList);
    PortStringPositions = strfind(string, '/dev/ttyACM');
    nPorts = length(PortStringPositions);
    CandidatePorts = cell(1,nPorts);
    nGoodPorts = 0;
    for x = 1:nPorts
        if PortStringPositions(x)+11 <= length(string)
            CandidatePort = strtrim(string(PortStringPositions(x):PortStringPositions(x)+11));
            nGoodPorts = nGoodPorts + 1;
            CandidatePorts{nGoodPorts} = CandidatePort;
        end
    end
    ArduinoPorts = CandidatePorts(1:nGoodPorts);
end