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

% SmartServoModule is a class to interface with the Bpod Smart Servo Module
% via its USB connection to the PC.
%
% User-configurable device parameters are exposed as class properties. Setting
% the value of a property will trigger its 'set' method to update the device.
%
% The Smart Servo Module has 3 channels, each of which control up to 8
% daisy-chained motors.
%
% Example usage:
%
% S = SmartServoModule('COM3'); % Create an instance of SmartServoModule,
%                               connecting to the Bpod Smart Servo Module on port COM3
% myServo = S.newSmartServo(2, 1); % Create myServo, an object to control
%                                    the servo on channel 2 at position 1
% myServo.setPosition(90); % Move servo shaft to 90 degrees using default velocity and acceleration
% myServo.setPosition(0, 100, 200); % Return shaft to 0 degrees at 100RPM with 200RPM^2 acceleration
% myServo.setMode(4); % Set servo to continuous rotation mode with velocity control
% myServo.setVelocity(-10); % Start rotating clockwise at 10RPM
% myServo.setVelocity(0); % Stop rotating
% clear myServo; clear S; % clear the objects from the workspace, releasing the USB serial port

classdef SmartServoModule < handle

    properties
        port % ArCOM Serial port
    end

    methods
        function obj = SmartServoModule(portString)
            % Constructor

            % Open the USB Serial Port
            obj.port = ArCOMObject_Bpod(portString, 480000000);
        end
        function smartServo = newSmartServo(obj, channel, address)
            % Create a new smart servo object, addressing a single motor on the module
            % Arguments:
            % channel: The target motor's channel on the smart servo module (1-3)
            % address: The target motor's address on the target channel (1-8)
            %
            % Returns:
            % smartServo, an instance of SmartServoInterface.m connected addressing the target servo
                smartServo = SmartServoInterface(obj.port, channel, address);
        end
        function bytes = param2Bytes(paramValue)
            % Convenience function for state machine control. Position,
            % velocity, acceleration, current and RPM values must be
            % converted to bytes for use with the state machine serial interface.
            % Arguments:
            % paramValue, the value of the parameter to convert (type = double or single)
            %
            % Returns:
            % bytes, a 1x4 vector of bytes (type = uint8)
            bytes = typecast(single(paramValue), 'uint8');
        end
        function delete(obj)
            obj.port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end

    end
end