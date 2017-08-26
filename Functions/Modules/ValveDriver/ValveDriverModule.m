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
classdef ValveDriverModule < handle
    properties
        Port % ArCOM Serial port
        isOpen = zeros(1,8);
    end
    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end
    properties (Access = private)
        CurrentFirmwareVersion = 1;
        Initialized = 0; % Set to 1 after constructor finishes running
    end
    methods
        function obj = ValveDriverModule(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write(255, 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 254
                error('Could not connect =( ')
            end
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.CurrentFirmwareVersion
                error(['Error: old firmware detected - v' obj.FirmwareVersion '. The current version is: ' obj.CurrentFirmwareVersion '. Please update the I2C messenger firmware using Arduino.'])
            end
            obj.Initialized = 1;
        end
        function set.isOpen(obj, stateVector)
            if obj.Initialized
                if (length(stateVector) < 8)
                    error('Error: You must provide a vector of 8 states (or modify one position of the .isOpen vector) to open or close valves.')
                end
                ValveBits = sum((stateVector).*(2.^(0:7)));
                obj.Port.write(['B' ValveBits], 'uint8');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting valves. Confirm code not returned.');
                end
            end
            obj.isOpen = stateVector;
        end
        function openValve(obj,valveID)
            obj.isOpen(valveID) = 1;
            ValveBits = sum((obj.isOpen).*(2.^(0:7)));
            obj.Port.write(['B' ValveBits], 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting valves. Confirm code not returned.');
            end
        end
        function closeValve(obj,valveID)
            obj.isOpen(valveID) = 0;
            ValveBits = sum((obj.isOpen).*(2.^(0:7)));
            obj.Port.write(['B' ValveBits], 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting valves. Confirm code not returned.');
            end
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end