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

% I2CMessenger is a class to interface with the I2C Messenger Module
% via its USB connection to the PC.
%
% User-configurable device parameters are exposed as class properties. Setting
% the value of a property will trigger its 'set' method to update the device.

classdef I2CMessenger < handle
    properties
        Port % ArCOM Serial port
        SlaveAddress = 1; % The current I2C slave address
        TransferSpeed = 'FastMode'; % 'FastMode' = 400Kb/s, 'Standard' = 100Kb/s
        Mode = 'Relay';   % 'Relay' mode passes all UART bytes to the current I2C slave. 
                          % 'Message' mode: UART bytes code for messages (up to 16 bytes), 
                          %           and trigger transmission via I2C
                          % 'USBrelay' mode passes UART bytes to the USB serial connection
                          % 'USBmessage' mode passes triggered messages to USB instead of I2C
    end

    properties (SetAccess = protected)
        Messages = cell(1,256); % Library of triggerable I2C messages (up to 16 char)
        MessageAddress = ones(1,256); % Address of each message on the I2C bus (defaults to SlaveAddress)
        FirmwareVersion = 0;
    end

    properties (Access = private)
        currentFirmwareVersion = 1;
    end

    methods
        function obj = I2CMessenger(portString)
            % Constructor
            obj.Port = ArCOMObject(portString, 115200);
            obj.Port.write('C', 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 225
                error('Could not connect =( ')
            end
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.currentFirmwareVersion
                error(['Error: old firmware detected - v' obj.FirmwareVersion '. The current version is: '... 
                    obj.currentFirmwareVersion '. Please update the I2C messenger firmware using Arduino.'])
            end
            obj.Port.write('B', 'uint8');
            slaveadd = obj.Port.read(1, 'uint8');
            tSpeed = obj.Port.read(1, 'uint8');
            mode = obj.Port.read(1, 'uint8');
            obj.SlaveAddress = slaveadd;
            switch tSpeed
                case 0
                    obj.TransferSpeed = 'Standard';
                case 1
                    obj.TransferSpeed = 'FastMode';
            end
            switch mode
                case 0
                    obj.Mode = 'Relay';
                case 1
                    obj.Mode = 'Message';
                case 2
                    obj.Mode = 'USBrelay';
                case 3
                    obj.Mode = 'USBmessage';
            end
        end

        function set.SlaveAddress(obj, address)
            % Set the I2C slave address
            % Parameters: address, the slave address (0-127)
            obj.Port.write(['A' address], 'uint8');
            obj.confirmTransmission('slave address');
        end

        function set.TransferSpeed(obj, speed)
            % Set the transfer speed - I2C standard (100Kb/s) or fast mode (400Kb/s).
            % Parameters: speed (char array): 'Standard' or 'FastMode'
            switch lower(speed)
                case 'fastmode'
                    obj.Port.write(['R' 1], 'uint8');
                    transferSpeed = 'FastMode';
                case 'standard'
                    obj.Port.write(['R' 0], 'uint8');
                    transferSpeed = 'Standard';
                otherwise
                    error('Error: Invalid transfer speed. Valid speeds are Standard (100Kb/s) and FastMode (400Kb/s)')
            end
            obj.confirmTransmission('transfer speed');
            obj.TransferSpeed = transferSpeed;
        end

        function setMessage(obj, messageIndex, message, varargin) % optional argument: slave address
            % Sets a multi-byte message at an index. Each message has an optional target slave address
            % Parameters:
            % messageIndex, the index of the message to set
            % message: the message to load, a byte array up to 16 bytes long
            % slaveAddress (optional): The address of the I2C slave to receive the message when triggered
            if length(message) > 16
                error('Error: messages must be 16 bytes or less.')
            end
            if nargin > 3
                slaveAddress = varargin{1};
            else
                slaveAddress = obj.SlaveAddress;
            end
            obj.Port.write(['P' 1 messageIndex slaveAddress length(message) message], 'uint8');
            obj.confirmTransmission('new message');
            obj.Messages{messageIndex} = message;
            obj.MessageAddress(messageIndex) = slaveAddress;
        end

        function set.Mode(obj, mode)
            % Sets the mode of the I2C module.
            % Params: mode (char array), the operating mode of the I2C
            % module. Options are: 
            % 'Relay' Bytes from the state machine are relayed to the current slave address
            % 'Message' Bytes from the state machine encode message library indexes to send
            % 'USBrelay' Bytes from USB are relayed to the current slave address
            % 'USBmessage' Bytes from USB encode message library indexes to send
            switch lower(mode)
                case 'relay'
                    mode = 0;
                    obj.Mode = 'Relay';
                case 'message'
                    mode = 1;
                    obj.Mode = 'Message';
                case 'usbrelay'
                    mode = 2;
                    obj.Mode = 'USBrelay';
                case 'usbmessage'
                    mode = 3;
                    obj.Mode = 'USBmessage';
                otherwise
                    error(['Error: invalid mode ' mode '. Valid modes are: Relay, Message, USBrelay, USBmessage'])
            end
            obj.Port.write(['M' mode], 'uint8');
            obj.confirmTransmission('mode');
        end

        function bpodWrite(obj, byte)
            if length(byte) ~= 1 || byte > 255
                error('Error: input must be a byte.')
            end
            obj.Port.write(['S' byte], 'uint8');
        end

        function I2Cwrite(obj, bytestring)
            % Write bytes to the current I2C SlaveAddress
            message = zeros(1,1000); Ind = 1;
            for i = 1:length(bytestring)
                message(Ind) = 'I'; Ind = Ind + 1;
                message(Ind) = bytestring(i); Ind = Ind + 1;
            end
            message = message(1:Ind);
            obj.Port.write(message, 'uint8');
        end

        function triggerMessage(obj, message)
            % Trigger an outgoing message to be sent
            if length(message) ~= 1 || message > 255
                error('Error: message be a byte.')
            end
            obj.Port.write(['G' message], 'uint8');
        end

        function reset(obj)
            % Reset all messages to defaults
            obj.Port.write('X', 'uint8');
            obj.Messages = cell(1,256);
            obj.MessageAddress = ones(1,256);
            obj.SlaveAddress = 1;
            obj.TransferSpeed = 'FastMode';
            obj.Mode = 'Relay';
        end

        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end

    methods (Access = private)
        function confirmTransmission(obj, opName)
            % Read op confirmation byte, and throw an error if confirm not returned
            
            confirmed = obj.Port.read(1, 'uint8');
            if confirmed == 0
                error(['Error setting ' opName ': the module denied your request.'])
            elseif confirmed ~= 1
                error(['Error setting ' opName ': module did not acknowledge the operation.']);
            end
        end
    end
end