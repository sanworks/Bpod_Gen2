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
function USBSerialPorts = FindUSBSerialPorts(obj)
    USBSerialPorts = cell(0,1);
    if ispc
        [Status,RawString] = system('powershell.exe -inputformat none "[System.IO.Ports.SerialPort]::getportnames()"');
        nPortsAdded = 0;
        if ~isempty(RawString)
            PortLocations = strsplit(RawString,char(10));
            PortLocations = PortLocations(1:end-1);
            nPorts = length(PortLocations);
            for p = 1:nPorts
                CandidatePort = PortLocations{p};
                if ~strcmp(CandidatePort, 'COM1')
                    novelPort = 1;
                    if sum(strcmp(CandidatePort, USBSerialPorts)) > 0
                        novelPort = 0;
                    end
                    if novelPort == 1
                        nPortsAdded = nPortsAdded + 1;
                        USBSerialPorts{nPortsAdded} = CandidatePort;
                    end
                end
            end
        end
        
    elseif ismac % Contributed by Thiago Gouvea JUN_9_2016
        [trash, RawSerialPortList] = system('ls /dev/cu.usbmodem*');
        string = strtrim(RawSerialPortList);
        PortStringPositions = strfind(string, '/dev/cu.usbmodem');
        StringEnds = find(string == 9);
        nPorts = length(PortStringPositions);
        CandidatePorts = cell(1,nPorts);
        nGoodPorts = 0;
        for x = 1:nPorts
            if x < nPorts && nPorts > 1
                CandidatePort = string(PortStringPositions(x):StringEnds(x)-1);
            elseif x == nPorts
                CandidatePort = string(PortStringPositions(x):end);
            end
            nGoodPorts = nGoodPorts + 1;
            CandidatePorts{nGoodPorts} = CandidatePort;
        end
        USBSerialPorts = CandidatePorts(1:nGoodPorts);
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
        USBSerialPorts = CandidatePorts(1:nGoodPorts);
    end
end