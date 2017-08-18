%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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
classdef I2CMessenger < handle
    properties
        Port % ArCOM Serial port
        SlaveAddress = 1; % The current I2C slave address
        TransferSpeed = 'FastMode'; % 'FastMode' = 400Kb/s, 'Standard' = 100Kb/s
        Mode = 'Relay';   % 'Relay' mode passes all UART bytes to the current I2C slave. 
                          % 'Message' mode: UART bytes code for messages (up to 16 bytes), and trigger transmission via I2C
                          % 'USBrelay' mode passes UART bytes to the USB serial connection
                          % 'USBmessage' mode passes triggered messages to USB instead of I2C
    end
    properties (SetAccess = protected)
        Messages = cell(1,256); % Library of triggerable I2C messages (up to 16 char)
        MessageAddress = ones(1,256); % Address of each message on the I2C bus (defaults to SlaveAddress)
        FirmwareVersion = 0;
    end
    properties (Access = private)
        CurrentFirmwareVersion = 1;
    end
    methods
        function obj = I2CMessenger(portString)
            obj.Port = ArCOMObject(portString, 115200);
            obj.Port.write('C', 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 225
                error('Could not connect =( ')
            end
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.CurrentFirmwareVersion
                error(['Error: old firmware detected - v' obj.FirmwareVersion '. The current version is: ' obj.CurrentFirmwareVersion '. Please update the I2C messenger firmware using Arduino.'])
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
            obj.Port.write(['A' address], 'uint8');
            confirm = obj.Port.read(1, 'uint8');
            if ~confirm
                error('Error: failed to set slave address')
            end
        end
        function set.TransferSpeed(obj, speed)
            switch lower(speed)
                case 'fastmode'
                    obj.Port.write(['R' 1], 'uint8');
                    TransferSpeed = 'FastMode';
                case 'standard'
                    obj.Port.write(['R' 0], 'uint8');
                    TransferSpeed = 'Standard';
                otherwise
                    error('Error: Invalid transfer speed. Valid speeds are Standard (100Kb/s) and FastMode (400Kb/s)')
            end
            confirm = obj.Port.read(1, 'uint8');
            if ~confirm
                error('Error: failed to set transfer speed.')
            end
            obj.TransferSpeed = TransferSpeed;
        end
        function setMessage(obj, messageIndex, message, varargin) % optional argument: slave address
            if length(message) > 16
                error('Error: messages must be 16 bytes or less.')
            end
            if nargin > 3
                slaveAddress = varargin{1};
            else
                slaveAddress = obj.SlaveAddress;
            end
            obj.Port.write(['P' 1 messageIndex slaveAddress length(message) message], 'uint8');
            confirm = obj.Port.read(1, 'uint8');
            if ~confirm
                error('Error: failed to set new message')
            end
            obj.Messages{messageIndex} = message;
            obj.MessageAddress(messageIndex) = slaveAddress;
        end
        function set.Mode(obj, mode)
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
            confirm = obj.Port.read(1, 'uint8');
            if ~confirm
                error('Error: failed to set mode.')
            end
        end
        function bpodWrite(obj, byte)
            if length(byte) ~= 1 || byte > 255
                error('Error: input must be a byte.')
            end
            obj.Port.write(['S' byte], 'uint8');
        end
        function I2Cwrite(obj, bytestring)
            Message = zeros(1,1000); Ind = 1;
            for i = 1:length(bytestring)
                Message(Ind) = 'I'; Ind = Ind + 1;
                Message(Ind) = bytestring(i); Ind = Ind + 1;
            end
            Message = Message(1:Ind);
            obj.Port.write(Message, 'uint8');
        end
        function triggerMessage(obj, message)
            if length(message) ~= 1 || message > 255
                error('Error: message be a byte.')
            end
            obj.Port.write(['G' message], 'uint8');
        end
        function reset(obj)
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
end