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

classdef SmartServoInterface < handle

    properties
        port % ArCOM Serial port
        motorInfo % Struct with info about  the motor (detected model name within Dynamixel X series, etc)
        channel % Channel on the SmartServoModule device
        address % Index of the target motor on the selected channel
        motorMode % Mode 1 = Position. 2 = Extended Position. 3 = Current-limited position 4 = RPM
    end

    properties (Access = private)
        ctrlTable % Control table listing addresses of registers in motor controller
    end

    methods
        function obj = SmartServoInterface(port, channel, address, modelName)
            obj.ctrlTable = obj.setupControlTable;
            obj.port = port;
            obj.motorInfo = struct;
            obj.motorInfo.modelName = modelName;
            obj.channel = channel;
            obj.address = address;
            obj.motorMode = 1;
            obj.setMaxVelocity(0); % Reset velocity to motor default (max)
            obj.setMaxAcceleration(0); % Reset acceleration to motor default (max)
            obj.motorInfo.firmwareVersion = obj.readControlTable(obj.ctrlTable.firmwareVersion);
        end

        function set.motorMode(obj, newMode)
            % Mode 1 = Position. 2 = Extended Position. 3 = Current-limited position 4 = RPM
            obj.port.write(['M' obj.channel obj.address newMode], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting mode. Confirm code not returned.');
            end
            obj.motorMode = newMode;
        end

        function setPosition(obj, newPosition, varargin)
            % setPosition() sets the position of the motor shaft, in
            % degrees of rotation.
            % Required Arguments: 
            % channel: The motor's channel on the smart servo module (1-3)
            % address: The motor's position on the selected channel's (1-8)
            % newPosition: The target position (units = degrees, range = 0-360)
            % Optional Arguments (must both be passed in the following order):
            % maxVelocity: Maximum velocity enroute to target position (units = rev/min, 0 = Max)
            % maxAccel: Maximum acceleration enroute to target position (units = rev/min^2, 0 = Max)
            % Note: Max velocity and acceleration become the new settings for future movements.

            if ~(obj.motorMode == 1 || obj.motorMode == 2)
                error(['Motor ' num2str(obj.address) ' on channel ' num2str(obj.channel)... 
                       ' must be in a position mode (modes 1 or 2) before calling setPosition().'])
            end
            posBytes = typecast(single(newPosition), 'uint8');
            isPositionOnly = true;
            if nargin > 3
                isPositionOnly = false;
                maxVelocity = varargin{1};
                maxAccel = varargin{2};
                velBytes = typecast(single(maxVelocity), 'uint8');
                accBytes = typecast(single(maxAccel), 'uint8');
            end
            if isPositionOnly
                obj.port.write(['P' obj.channel obj.address posBytes], 'uint8');
            else
                obj.port.write(['G' obj.channel obj.address posBytes velBytes accBytes], 'uint8');
            end
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting position. Confirm code not returned.');
            end
        end

        function setCurrentLimitedPos(obj, newPosition, currentPercent)
            % Position Units = Degrees
            % Current units = Percent of max
            if obj.motorMode(obj.channel, obj.address) ~= 3
                error(['Motor ' num2str(obj.address) ' on channel ' num2str(obj.channel)... 
                       ' must be in current-limited position mode (mode 3) before calling setCurrentLimitedPos().'])
            end
            posBytes = typecast(single(newPosition), 'uint8');
            currentLimitBytes = typecast(single(currentPercent), 'uint8');
            obj.port.write(['C' obj.channel obj.address posBytes currentLimitBytes], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting position. Confirm code not returned.');
            end
        end

        function setMaxVelocity(obj, maxVelocity)
            maxVelocityBytes = typecast(single(maxVelocity), 'uint8');
            obj.port.write(['[' obj.channel obj.address maxVelocityBytes], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting position. Confirm code not returned.');
            end
        end

        function setMaxAcceleration(obj, maxAcceleration)
            maxAccBytes = typecast(single(maxAcceleration), 'uint8');
            obj.port.write([']' obj.channel obj.address maxAccBytes], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting position. Confirm code not returned.');
            end
        end

        function setRPM(obj, newRPM)
            % Units = rev/min
            if obj.motorMode(obj.channel, obj.address) ~= 4
                error(['Motor ' num2str(obj.address) ' on channel ' num2str(obj.channel)... 
                       ' must be in RPM mode (mode 4) before calling setRPM().'])
            end
            rpmBytes = typecast(single(newRPM), 'uint8');
            obj.port.write(['V' obj.channel obj.address rpmBytes], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting RPM. Confirm code not returned.');
            end
        end

        function pos = getPosition(obj)
            obj.port.write(['R' obj.channel obj.address], 'uint8');
            posBytes = obj.port.read(4, 'uint8');
            pos = typecast(posBytes, 'single');
        end

        function temp = getTemperature(obj)
            temp = obj.readControlTable(obj.ctrlTable.currentTemperature);
        end

        function value = readControlTable(obj, tableAddress)
            obj.port.write(['T' obj.channel obj.address tableAddress], 'uint8');
            valBytes = obj.port.read(4, 'uint8');
            value = typecast(valBytes, 'single');
        end

        function delete(obj)
            obj.port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end

    methods (Access = private)
        function ctrlTable = setupControlTable(obj)
            ctrlTable = struct;
            ctrlTable.firmwareVersion = 6;
            ctrlTable.motorAddress = 7;
            ctrlTable.hardwareError = 70;
            ctrlTable.isMoving = 122;
            ctrlTable.currentCurrent = 126;
            ctrlTable.currentVelocity = 128;
            ctrlTable.currentInputVoltage = 144;
            ctrlTable.currentTemperature = 146;
        end
    end
end