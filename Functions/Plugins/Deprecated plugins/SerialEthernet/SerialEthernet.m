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
function SerialEthernet(Command, varargin)
global BpodSystem
Command = lower(Command);
switch Command
    case 'init'
        ComPort = varargin{1};
        if ~isfield(BpodSystem.PluginSerialPorts, 'SerialEthernetPort')
            BpodSystem.PluginSerialPorts.SerialEthernetPort = serial(ComPort, 'BaudRate', 115200, 'Timeout', 1, 'DataTerminalReady', 'on');
            try
                fopen(BpodSystem.PluginSerialPorts.SerialEthernetPort);
            catch
                error(['Error opening open serial port on ' ComPort])
            end
        end
        fwrite(BpodSystem.PluginSerialPorts.SerialEthernetPort,'I', 'uint8');
        try
            fread(BpodSystem.PluginSerialPorts.SerialEthernetPort, 1);
        catch
            error('SerialEthernet port successfully opened but SerialEthernet module did not acknowledge transmission')
        end
        disp(['SerialEthernet client opened on port ' ComPort])
    case 'connect'
        RemoteIP = varargin{1};
        RemotePort = varargin{2};
        IPString = [num2str(RemoteIP(1)) '.' num2str(RemoteIP(2)) '.' num2str(RemoteIP(3)) '.' num2str(RemoteIP(4))];
        fwrite(BpodSystem.PluginSerialPorts.SerialEthernetPort, ['C' RemoteIP], 'uint8');
        fwrite(BpodSystem.PluginSerialPorts.SerialEthernetPort, RemotePort, 'uint16');
        Reply = fread(BpodSystem.PluginSerialPorts.SerialEthernetPort, 1);
        if Reply ~= 1
            error('Error connecting to remote Ethernet server')
        end
        disp(['SerialEthernet connected to server on IP: ' IPString])
    case 'loadstring'
        StringNum = varargin{1};
        String = varargin{2};
        fwrite(BpodSystem.PluginSerialPorts.SerialEthernetPort, ['L' StringNum length(String) String], 'uint8');
    case 'triggerstring'
        StringNum = varargin{1};
        fwrite(BpodSystem.PluginSerialPorts.SerialEthernetPort, ['T' StringNum], 'uint8');
    case 'messagemode'
        Mode = varargin{1};
        fwrite(BpodSystem.PluginSerialPorts.SerialEthernetPort, ['M' Mode], 'uint8');
    case 'close'
        fwrite(BpodSystem.PluginSerialPorts.SerialEthernetPort, 'X', 'uint8');
        pause(.1);
        fclose(BpodSystem.PluginSerialPorts.SerialEthernetPort);
        delete(BpodSystem.PluginSerialPorts.SerialEthernetPort);
        rmfield(BpodSystem.PluginSerialPorts, 'SerialEthernetPort');
end