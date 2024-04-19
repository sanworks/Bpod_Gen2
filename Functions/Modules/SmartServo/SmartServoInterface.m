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
        ctrlTable % Control table listing addresses of registers in motor controller
        motorInfo % Struct with info about  the motor (detected model name within Dynamixel X series, etc)
        channel % Channel on the SmartServoModule device
        address % Index of the target motor on the selected channel
        motorMode % Mode 1 = Position. 2 = Extended Position. 3 = Current-limited position 4 = RPM
    end

    properties (Access = private)
        opMenuByte = 212; % Byte code to access op menu via USB
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
            obj.motorInfo.firmwareVersion = obj.readControlTable(obj.ctrlTable.FIRMWARE_VERSION);
        end

        function set.motorMode(obj, newMode)
            % Mode 1 = Position. 2 = Extended Position. 3 = Current-limited position 4 = RPM
            obj.port.write([obj.opMenuByte 'M' obj.channel obj.address newMode], 'uint8');
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
            % blocking: 1: Block the MATLAB command prompt until move is complete. 0: Don't.
            % Note: Max velocity and acceleration become the new settings for future movements.

            if ~(obj.motorMode == 1 || obj.motorMode == 2)
                error(['Motor ' num2str(obj.address) ' on channel ' num2str(obj.channel)... 
                       ' must be in a position mode (modes 1 or 2) before calling setPosition().'])
            end
            posBytes = typecast(single(newPosition), 'uint8');
            isPositionOnly = true;
            maxVelocity = 0;
            maxAccel = 0;
            blocking = 0;
            if nargin > 2
                isPositionOnly = false;
                maxVelocity = varargin{1};
                velBytes = typecast(single(maxVelocity), 'uint8');
            end
            if nargin > 3
                maxAccel = varargin{2};
                accBytes = typecast(single(maxAccel), 'uint8');
            end
            if nargin > 4
                blocking = varargin{3};
            end

                
            if isPositionOnly
                obj.port.write([obj.opMenuByte 'P' obj.channel obj.address posBytes], 'uint8');
            else
                obj.port.write([obj.opMenuByte 'G' obj.channel obj.address blocking posBytes velBytes accBytes], 'uint8');
            end
            if blocking
                while obj.port.bytesAvailable == 0
                    pause(.0001);
                end
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
            obj.port.write([obj.opMenuByte 'C' obj.channel obj.address posBytes currentLimitBytes], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting position. Confirm code not returned.');
            end
        end

        function setMaxVelocity(obj, maxVelocity)
            maxVelocityBytes = typecast(single(maxVelocity), 'uint8');
            obj.port.write([obj.opMenuByte '[' obj.channel obj.address maxVelocityBytes], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting position. Confirm code not returned.');
            end
        end

        function setMaxAcceleration(obj, maxAcceleration)
            maxAccBytes = typecast(single(maxAcceleration), 'uint8');
            obj.port.write([obj.opMenuByte ']' obj.channel obj.address maxAccBytes], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting position. Confirm code not returned.');
            end
        end

        function setRPM(obj, newRPM)
            % Units = rev/min
            if obj.motorMode ~= 4
                error(['Motor ' num2str(obj.address) ' on channel ' num2str(obj.channel)... 
                       ' must be in RPM mode (mode 4) before calling setRPM().'])
            end
            rpmBytes = typecast(single(newRPM), 'uint8');
            obj.port.write([obj.opMenuByte 'V' obj.channel obj.address rpmBytes], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting RPM. Confirm code not returned.');
            end
        end

        function pos = getPosition(obj)
            obj.port.write([obj.opMenuByte '+' obj.channel obj.address], 'uint8');
            posBytes = obj.port.read(4, 'uint8');
            pos = typecast(posBytes, 'single');
        end

        function temp = getTemperature(obj)
            temp = obj.readControlTable(obj.ctrlTable.currentTemperature);
        end

        function value = readControlTable(obj, tableAddress)
            obj.port.write([obj.opMenuByte 'T' obj.channel obj.address tableAddress], 'uint8');
            valBytes = obj.port.read(4, 'uint8');
            value = typecast(valBytes, 'int32');
        end

        function delete(obj)
            obj.port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end

    methods (Access = private)
        function ctrlTable = setupControlTable(obj)
           % Returns a table with references to Dynamixel protocol 2.0
           % control table items as per the Dynamixel2Arduino library at:
           % https://github.com/ROBOTIS-GIT/Dynamixel2Arduino/blob/master/src/actuator.h
           % These can be used with the readControlTable() method to read
           % a target motor's internal registers.
           % NOTE: The control table indexes are different from the control
           % table addresses in a specific motor's datasheet.
           % Dynamixel2Arduino converts these to the appropriate address for each motor.
           ctrlTable = struct;
           ctrlTable.MODEL_NUMBER = 0;
           ctrlTable.MODEL_INFORMATION = 1;
           ctrlTable.FIRMWARE_VERSION = 2;
           ctrlTable.PROTOCOL_VERSION = 3;
           ctrlTable.ID = 4;
           ctrlTable.SECONDARY_ID = 5;
           ctrlTable.BAUD_RATE = 6;
           ctrlTable.DRIVE_MODE = 7;
           ctrlTable.CONTROL_MODE = 8;
           ctrlTable.OPERATING_MODE = 9;
           ctrlTable.CW_ANGLE_LIMIT = 10;
           ctrlTable.CCW_ANGLE_LIMIT = 11;
           ctrlTable.TEMPERATURE_LIMIT = 12;
           ctrlTable.MIN_VOLTAGE_LIMIT = 13;
           ctrlTable.MAX_VOLTAGE_LIMIT = 14;
           ctrlTable.PWM_LIMIT = 15;
           ctrlTable.CURRENT_LIMIT = 16;
           ctrlTable.VELOCITY_LIMIT = 17;
           ctrlTable.MAX_POSITION_LIMIT = 18;
           ctrlTable.MIN_POSITION_LIMIT = 19;
           ctrlTable.ACCELERATION_LIMIT = 20;
           ctrlTable.MAX_TORQUE = 21;
           ctrlTable.HOMING_OFFSET = 22;
           ctrlTable.MOVING_THRESHOLD = 23;
           ctrlTable.MULTI_TURN_OFFSET = 24;
           ctrlTable.RESOLUTION_DIVIDER = 25;
           ctrlTable.EXTERNAL_PORT_MODE_1 = 26;
           ctrlTable.EXTERNAL_PORT_MODE_2 = 27;
           ctrlTable.EXTERNAL_PORT_MODE_3 = 28;
           ctrlTable.EXTERNAL_PORT_MODE_4 = 29;
           ctrlTable.STATUS_RETURN_LEVEL = 30;
           ctrlTable.RETURN_DELAY_TIME = 31;
           ctrlTable.ALARM_LED = 32;
           ctrlTable.SHUTDOWN = 33;
           ctrlTable.TORQUE_ENABLE = 34;
           ctrlTable.LED = 35;
           ctrlTable.LED_RED = 36;
           ctrlTable.LED_GREEN = 37;
           ctrlTable.LED_BLUE = 38;
           ctrlTable.REGISTERED_INSTRUCTION = 39;
           ctrlTable.HARDWARE_ERROR_STATUS = 40;
           ctrlTable.VELOCITY_P_GAIN = 41;
           ctrlTable.VELOCITY_I_GAIN = 42;
           ctrlTable.POSITION_P_GAIN = 43;
           ctrlTable.POSITION_I_GAIN = 44;
           ctrlTable.POSITION_D_GAIN = 45;
           ctrlTable.FEEDFORWARD_1ST_GAIN = 46;
           ctrlTable.FEEDFORWARD_2ND_GAIN = 47;
           ctrlTable.P_GAIN = 48;
           ctrlTable.I_GAIN = 49;
           ctrlTable.D_GAIN = 50;
           ctrlTable.CW_COMPLIANCE_MARGIN = 51;
           ctrlTable.CCW_COMPLIANCE_MARGIN = 52;
           ctrlTable.CW_COMPLIANCE_SLOPE = 53;
           ctrlTable.CCW_COMPLIANCE_SLOPE = 54;
           ctrlTable.GOAL_PWM = 55;
           ctrlTable.GOAL_TORQUE = 56;
           ctrlTable.GOAL_CURRENT = 57;
           ctrlTable.GOAL_POSITION = 58;
           ctrlTable.GOAL_VELOCITY = 59;
           ctrlTable.GOAL_ACCELERATION = 60;
           ctrlTable.MOVING_SPEED = 61;
           ctrlTable.PRESENT_PWM = 62;
           ctrlTable.PRESENT_LOAD = 63;
           ctrlTable.PRESENT_SPEED = 64;
           ctrlTable.PRESENT_CURRENT = 65;
           ctrlTable.PRESENT_POSITION = 66;
           ctrlTable.PRESENT_VELOCITY = 67;
           ctrlTable.PRESENT_VOLTAGE = 68;
           ctrlTable.PRESENT_TEMPERATURE = 69;
           ctrlTable.TORQUE_LIMIT = 70;
           ctrlTable.REGISTERED = 71;
           ctrlTable.MOVING = 72;
           ctrlTable.LOCK = 73;
           ctrlTable.PUNCH = 74;
           ctrlTable.CURRENT = 75;
           ctrlTable.SENSED_CURRENT = 76;
           ctrlTable.REALTIME_TICK = 77;
           ctrlTable.TORQUE_CTRL_MODE_ENABLE = 78;
           ctrlTable.BUS_WATCHDOG = 79;
           ctrlTable.PROFILE_ACCELERATION = 80;
           ctrlTable.PROFILE_VELOCITY = 81;
           ctrlTable.MOVING_STATUS = 82;
           ctrlTable.VELOCITY_TRAJECTORY = 83;
           ctrlTable.POSITION_TRAJECTORY = 84;
           ctrlTable.PRESENT_INPUT_VOLTAGE = 85;
        end
    end
end