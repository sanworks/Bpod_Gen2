%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2018 Sanworks LLC, Stony Brook, New York, USA

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
        MotorAttributes = ones(2,12);
    end
    methods
        function obj = PololuMaestro(portString)
            obj.Port = ArCOMObject_Bpod(portString, 9600);
            for Index = 1:6 % Initialize Channels
                [LowBits, HighBits] = obj.computeSerialCode(2^7);
                Output = [135 Index LowBits HighBits];
                obj.Port.write(Output, 'uint8');
                [LowBits, HighBits] = obj.computeSerialCode(2^(.9*7));
                Output = [137 Index LowBits HighBits];
                obj.Port.write(Output, 'uint8');
            end
        end
        function setMotor(obj,MotorID, Pos, varargin)
            if nargin < 4
                VEL = 1;
                ACC = 1;
            elseif nargin == 4
                VEL = varargin{1};
                ACC = 1;
            elseif nargin == 5
                VEL = varargin{1};
                ACC = varargin{2};
            end
            if VEL > 1
                VEL = 1;
            elseif VEL < 0
                VEL = 0;
            end
            if ACC > 1
                ACC = 1;
            elseif ACC < 0
                ACC = 0;
            end
            if VEL ~= obj.MotorAttributes(1,MotorID+1)
                Value = 2^(VEL*7);
                [LowBits, HighBits] = obj.computeSerialCode(Value);
                Output = [135 MotorID LowBits HighBits];
                obj.MotorAttributes(1,MotorID+1) = VEL;
                obj.Port.write(Output, 'uint8');
            end
            if ACC+.1 ~= obj.MotorAttributes(2,MotorID+1)
                Value = 2^(ACC*7);
                [LowBits, HighBits] = obj.computeSerialCode(Value);
                Output = [137 MotorID LowBits HighBits];
                obj.MotorAttributes(2,MotorID+1) = ACC+.1;
                obj.Port.write(Output, 'uint8');
            end
            MotorValue = ((((Pos+1)/2)*1000) + 1000)*4;
            [LowBits, HighBits] = obj.computeSerialCode(MotorValue);
            Output = [132 MotorID LowBits HighBits];
            obj.Port.write(Output, 'uint8');
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    methods (Access = private)
        function [LowBits, HighBits] = computeSerialCode(obj,Value)
            [~, ee] = log2(max(Value)); % This and next line = in-lined dec2bin
            MotorValue = char(rem(floor(Value*pow2(1-max(1,ee):0)),2)+'0');
            MotorOut = [ones(1,14-length(MotorValue))*48 MotorValue];
            TMOi = uint8(MotorOut(1:7)) - 48;
            TMOi = 1*TMOi(7) + 2*TMOi(6) + 4*TMOi(5) + 8*TMOi(4) + 16*TMOi(3) + 32*TMOi(2) + 64*TMOi(1);
            HighBits = int16(TMOi);
            TMOi = uint8(MotorOut(8:14)) - 48;
            TMOi = 1*TMOi(7) + 2*TMOi(6) + 4*TMOi(5) + 8*TMOi(4) + 16*TMOi(3) + 32*TMOi(2) + 64*TMOi(1);
            LowBits = int16(TMOi);
            if LowBits == 0
                LowBits = '0';
            end
        end
    end
end