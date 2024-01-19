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

% ValveDriverModule is a class to interface with the Bpod Valve Driver Module
% via its USB connection to the PC.
%
% User-configurable device parameters are exposed as class properties. Setting
% the value of a property will trigger its 'set' method to update the device.

classdef ValveDriverModule < handle
    properties
        Port % ArCOM Serial port
        isOpen = zeros(1,8);
    end

    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end

    properties (Access = private)
        currentFirmwareVersion = 2;
        initialized = 0; % Set to 1 after constructor finishes running
    end

    methods
        function obj = ValveDriverModule(portString)
            % Constructor

            % Open the USB Serial Port
            obj.Port = ArCOMObject_Bpod(portString, 115200);

            % Handshake
            obj.Port.write(255, 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 254
                error('Could not connect =( ')
            end

            % Read and verify firmware version
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.currentFirmwareVersion
                error(['Error: old firmware detected - v' obj.FirmwareVersion '. The current version is: ' ...
                    obj.currentFirmwareVersion '. Please update the valve driver firmware using LoadBpodFirmware().'])
            end
            obj.initialized = 1;
        end

        function set.isOpen(obj, stateVector)
            % Set valve states (open or closed)
            % Arguments: stateVector, a 1x8 array of values. 0 = closed, 1 = open
            if obj.initialized
                if (length(stateVector) < 8)
                    error(['Error: You must provide a vector of 8 states ' ...
                           '(or modify one position of the .isOpen vector) to open or close valves.'])
                end
                valveBits = sum((stateVector).*(2.^(0:7)));
                obj.Port.write(['B' valveBits], 'uint8');
                confirmed = obj.Port.read(1, 'uint8');
                if confirmed ~= 1
                    error('Error setting valves. Confirm code not returned.');
                end
            end
            obj.isOpen = stateVector;
        end

        function openValve(obj,valveID)
            % Open a specific valve
            % Arguments: valveID, the valve to open in range (1, 8)
            obj.isOpen(valveID) = 1;
            valveBits = sum((obj.isOpen).*(2.^(0:7)));
            obj.Port.write(['B' valveBits], 'uint8');
            confirmed = obj.Port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting valves. Confirm code not returned.');
            end
        end

        function closeValve(obj,valveID)
            % Close a specific valve
            % Arguments: valveID, the valve to close in range (1, 8)
            obj.isOpen(valveID) = 0;
            valveBits = sum((obj.isOpen).*(2.^(0:7)));
            obj.Port.write(['B' valveBits], 'uint8');
            confirmed = obj.Port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting valves. Confirm code not returned.');
            end
        end

        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end