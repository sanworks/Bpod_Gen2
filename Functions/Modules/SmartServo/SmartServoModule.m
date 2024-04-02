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

    properties (Access = private)
        modelNumbers = [1200 1190 1090 1060 1070 1080 1220 1210 1240 1230 1160 1120 1130 1020 1030 ...
                        1100 1110 1010 1000];
        modelNames = {'XL330-M288', 'XL330-M077', '2XL430-W250', 'XL430-W250',...
                      'XC430-T150/W150', 'XC430-T240/W240', 'XC330-T288', 'XC330-T181',...
                      'XC330-M288', 'XC330-M181', '2XC430-W250', 'XM540-W270', 'XM540-W150',...
                      'XM430-W350', 'XM430-W210', 'XH540-W270', 'XH540-W150', 'XH430-W210', 'XH430-W350'};
        isActive = zeros(3, 253);
        isConnected = zeros(3, 253);
        detectedModelName = cell(3, 253);
    end

    methods
        function obj = SmartServoModule(portString)
            % Constructor

            % Open the USB Serial Port
            obj.port = ArCOMObject_Bpod(portString, 480000000);
            obj.detectMotors;
        end

        function smartServo = newSmartServo(obj, channel, address)
            % Create a new smart servo object, addressing a single motor on the module
            % Arguments:
            % channel: The target motor's channel on the smart servo module (1-3)
            % address: The target motor's address on the target channel (1-8)
            %
            % Returns:
            % smartServo, an instance of SmartServoInterface.m connected addressing the target servo
                if obj.isConnected(channel, address)
                    smartServo = SmartServoInterface(obj.port, channel, address, obj.detectedModelName{channel, address});
                    obj.isActive(channel, address) = 1;
                else
                    error(['No motor registered on channel ' num2str(channel) ' at address ' num2str(address) '.' ...
                           char(10) 'If a new servo was recently connected, run detectMotors().'])
                end
        end

        function detectMotors(obj)
            disp('Detecting motors...');
            obj.port.write('D', 'uint8');
            pause(3);
            nMotorsFound = floor(obj.port.bytesAvailable/6);
            for i = 1:nMotorsFound
                motorChannel = obj.port.read(1, 'uint8');
                motorAddress = obj.port.read(1, 'uint8');
                motorModel = obj.port.read(1, 'uint32');
                modelName = 'Unknown model';
                modelNamePos = find(motorModel == obj.modelNumbers);
                if ~isempty(modelNamePos)
                    modelName = obj.modelNames{modelNamePos};
                end
                obj.isConnected(motorChannel, motorAddress) = 1;
                obj.detectedModelName{motorChannel, motorAddress} = modelName;
                disp(['Found: Ch: ' num2str(motorChannel) ' Address: ' num2str(motorAddress) ' Model: ' modelName]);
            end
        end

        function setMotorAddress(obj, motorChannel, currentAddress, newAddress)
            % Set the motor address on a given channel. Useful for
            % setting up a daisy-chain configuration.
            if obj.isActive(motorChannel, currentAddress)
                error(['setMotorAddress() cannot be used if an object to control the target motor has ' ...
                       char(10) 'already been created with newSmartServo().'])
            end
            if ~obj.isConnected(motorChannel, currentAddress)
                error(['No motor registered on channel ' num2str(motorChannel) ' at address ' num2str(currentAddress) '.' ...
                           char(10) 'If a new servo was recently connected, run detectMotors().'])
            end
            % Sets the network address of a motor on a given channel
            obj.port.write(['I' motorChannel currentAddress newAddress], 'uint8');
            confirmed = obj.port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error setting motor address. Confirm code not returned.');
            end
            obj.isConnected(motorChannel, currentAddress) = 0;
            disp('Address changed.')
            obj.detectMotors;
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