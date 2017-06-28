%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Sound Beach, New York, USA

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
classdef DDSModule < handle
    properties
        Port % ArCOM Serial port
        Frequency = 2000; % Last frequency set from plugin object (Hz)
        Amplitude = 1; % Last amplitude set from plugin object, in range [0 1] where 0 = 150mV p2p and 1 = 650mV p2p
        Waveform = 'Sine'; % 'Sine' or 'Triangle'
        MapFcn = 'Exp'; % Input bits from module serial channel mapped to frequency by either 'Linear' or 'Exp'
        OutputMapRange = [20 17000]; % Range of output frequency mapping function (Hz)
    end
    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end
    properties (Access = private)
        CurrentFirmwareVersion = 1;
        ValidWaveforms = {'Sine', 'Triangle'};
        ValidMapFunctions = {'Linear', 'Exp'};
        Initialized = 0; % Set to 1 after constructor finishes running
    end
    methods
        function obj = DDSModule(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write(251, 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 252
                error('Could not connect =( ')
            end
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.CurrentFirmwareVersion
                error(['Error: old firmware detected - v' obj.FirmwareVersion '. The current version is: ' obj.CurrentFirmwareVersion '. Please update the I2C messenger firmware using Arduino.'])
            end
            obj.GetParams;
            obj.Initialized = 1;
        end
        function set.Frequency(obj, freq)
            if obj.Initialized
                obj.Port.write('F', 'uint8', freq*1000, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting frequency. Confirm code not returned.');
                end
            end
            obj.Frequency = freq;
        end
        function set.OutputMapRange(obj, newRange)
            if length(newRange) ~= 2
                error('Error: map range must be a vector of 2 numbers - the lower and upper bound (Hz)')
            end
            if newRange(1) < 1 || newRange(2) > 100000
                error('Error: map range must cannot exceed [1 100000]')
            end
            if newRange(1) > newRange(2)
                error('Error: map range vector must increase: [LowBound HighBound]')
            end
            if obj.Initialized
                obj.Port.write('R', 'uint8', newRange, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting output map range. Confirm code not returned.');
                end
            end
            obj.OutputMapRange = newRange;
        end
        function set.Amplitude(obj, amp)
            if obj.Initialized
                if amp < 0 || amp > 1
                    error('Error: amplitude must be in range [0,1]')
                end
                ampValue = floor(amp*10000);
                obj.Port.write('A', 'uint8', ampValue, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting amplitude. Confirm code not returned.');
                end
            end
            obj.Amplitude = amp;
        end
        function set.Waveform(obj,waveform)
            WaveIndex = find(strcmpi(waveform, obj.ValidWaveforms));
            if isempty(WaveIndex)
                error(['Error: ' waveform ' is an invalid waveform name. Valid names are: Sine, Triangle'])
            end
            if obj.Initialized
                obj.Port.write(['W' WaveIndex-1], 'uint8');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting waveform. Confirm code not returned.');
                end
            end
            obj.Waveform = waveform;
        end
        function set.MapFcn(obj, functionName)
            FcnIndex = find(strcmpi(functionName, obj.ValidMapFunctions));
            if isempty(FcnIndex)
                error(['Error: ' functionName ' is an invalid map function name. Valid names are: Linear, Exp'])
            end
            if obj.Initialized
                obj.Port.write(['N' FcnIndex-1], 'uint8');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting map function. Confirm code not returned.');
                end
            end
            obj.MapFcn = functionName;
        end
        function map2Freq(obj, Value16Bit)
            if Value16Bit < 0 || Value16Bit > (2^16)-1
                error('Error: value must be in 16-bit range [0 (2^16)-1]')
            end
            obj.Port.write('M', 'uint8', Value16Bit, 'uint16');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting mapped frequency. Confirm code not returned.');
            end
            obj.Port.write('V', 'uint8'); % Request frequency
            obj.Initialized = 0; % Temporarily disable object -> hardware sync
            obj.Frequency = double(obj.Port.read(1, 'uint32'))/1000;
            obj.Initialized = 1;
        end
        function GetParams(obj)
            obj.Port.write('Q', 'uint8'); % Request settings
            obj.Frequency = double(obj.Port.read(1, 'uint32'))/1000;
            obj.Amplitude = (double(obj.Port.read(1, 'uint32'))/1000)/10000;
            obj.Waveform = obj.ValidWaveforms{obj.Port.read(1, 'uint8')+1};
            obj.MapFcn = obj.ValidMapFunctions{obj.Port.read(1, 'uint8')+1};
            obj.OutputMapRange = double(obj.Port.read(2, 'uint32'))/1000;
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end