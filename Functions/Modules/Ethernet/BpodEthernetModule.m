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

% BpodEthernetModule is a class to interface with the Bpod Ethernet Module
% via its USB connection to the PC. It allows the user to configure a
% library of outgoing messages, and trigger them by index.

classdef BpodEthernetModule < handle
    properties
        Port % ArCOM Serial port
    end
    properties (Access = protected)
        MessageLibrary = cell(1,256);
    end
    properties (Access = private)
        MaxMessageLength = 128;
    end
    methods
        function obj = BpodEthernetModule(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
        end
        function OK = setMessage(obj, messageNum, messageBytes)
            if (messageNum < 0) || (messageNum > 255)
                error('Error: Message index must be in range 0-255')
            end
            mLength = length(messageBytes);
            if mLength > obj.MaxMessageLength
                error(['Error: Message length must be ' num2str(obj.MaxMessageLength) ' bytes or less'])
            end
            obj.Port.write(['M' messageNum mLength messageBytes], 'uint8');
            OK = obj.Port.read(1, 'uint8');
        end
        function triggerMessage(obj, messageNum)
            if (messageNum < 0) || (messageNum > 255)
                error('Error: Message index must be in range 0-255')
            end
            obj.Port.write(['T' messageNum]);
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end