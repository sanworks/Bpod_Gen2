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

% PololuMaestro is an interface class for Pololu's Maestro servo
% controllers. It allows control of servo position, velocity and
% acceleration via USB.

% Example usage:
% P = PololuMaestro('COM3') % Where COM3 is the Maestro USB serial command port
% P.setMotor(MotorID, Position, [Velocity], [Acceleration])
%
% Position range: [-1 1]
% Velocity range: [0 1]
% Acceleration range: [0 1]
%
% clear P % Clear object and disconnect MATLAB from serial port

classdef PololuMaestro < handle
    properties
        Port % ArCOM Serial port
    end
    properties (Access = private)
        motorAttributes = ones(2,12);
    end
    methods
        function obj = PololuMaestro(portString)
            obj.Port = ArCOMObject_Bpod(portString, 9600);
            for i = 1:6 % Initialize Channels
                [lowBits, highBits] = obj.computeSerialCode(2^7);
                output = [135 i lowBits highBits];
                obj.Port.write(output, 'uint8');
                [lowBits, highBits] = obj.computeSerialCode(2^(.9*7));
                output = [137 i lowBits highBits];
                obj.Port.write(output, 'uint8');
            end
        end
        function setMotor(obj,motorID, pos, varargin)
            if nargin < 4
                vel = 1;
                acc = 1;
            elseif nargin == 4
                vel = varargin{1};
                acc = 1;
            elseif nargin == 5
                vel = varargin{1};
                acc = varargin{2};
            end
            if vel > 1
                vel = 1;
            elseif vel < 0
                vel = 0;
            end
            if acc > 1
                acc = 1;
            elseif acc < 0
                acc = 0;
            end
            if vel ~= obj.motorAttributes(1,motorID+1)
                value = 2^(vel*7);
                [lowBits, highBits] = obj.computeSerialCode(value);
                output = [135 motorID lowBits highBits];
                obj.motorAttributes(1,motorID+1) = vel;
                obj.Port.write(output, 'uint8');
            end
            if acc+.1 ~= obj.motorAttributes(2,motorID+1)
                value = 2^(acc*7);
                [lowBits, highBits] = obj.computeSerialCode(value);
                output = [137 motorID lowBits highBits];
                obj.motorAttributes(2,motorID+1) = acc+.1;
                obj.Port.write(output, 'uint8');
            end
            motorValue = ((((pos+1)/2)*1000) + 1000)*4;
            [lowBits, highBits] = obj.computeSerialCode(motorValue);
            output = [132 motorID lowBits highBits];
            obj.Port.write(output, 'uint8');
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    methods (Access = private)
        function [lowBits, highBits] = computeSerialCode(obj,value)
            [~, ee] = log2(max(value)); % This and next line = in-lined dec2bin
            motorValue = char(rem(floor(value*pow2(1-max(1,ee):0)),2)+'0');
            motorOut = [ones(1,14-length(motorValue))*48 motorValue];
            tmoi = uint8(motorOut(1:7)) - 48;
            tmoi = 1*tmoi(7) + 2*tmoi(6) + 4*tmoi(5) + 8*tmoi(4) + 16*tmoi(3) + 32*tmoi(2) + 64*tmoi(1);
            highBits = int16(tmoi);
            tmoi = uint8(motorOut(8:14)) - 48;
            tmoi = 1*tmoi(7) + 2*tmoi(6) + 4*tmoi(5) + 8*tmoi(4) + 16*tmoi(3) + 32*tmoi(2) + 64*tmoi(1);
            lowBits = int16(tmoi);
            if lowBits == 0
                lowBits = '0';
            end
        end
    end
end