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

% DDSModule is a class to interface with the Bpod DDS Module via its USB connection to the PC.
%
% User-configurable device parameters are exposed as class properties. Setting
% the value of a property will trigger its 'set' method to update the device.
%
% Usage Example:
% D = DDSModule('COM3'); % Create an instance of DDSModule,
%                          connecting to the DDS Module on port COM3
% D.Frequency = 10000; % Set the output waveform frequency to 10kHz
% D.Waveform = 'Triangle'; % Set the module to output a triangle waveform
%
% clear D; % clear the object from the workspace, releasing the USB serial port

classdef DDSModule < handle
    properties
        Port % ArCOM Serial port
        Frequency = 2000; % Last frequency set from plugin object (Hz)
        Amplitude = 1; % Last amplitude set from plugin object, in range [0 1] where 0 = 150mV p2p and 1 = 650mV p2p
        Waveform = 'Sine'; % 'Sine' or 'Triangle'
        MapFcn = 'Exp'; % Input bits from module serial channel mapped to frequency by either 'Linear' or 'Exp'
        InputBitRange = [0 65535]; % Range of input bits (e.g. from analog input module)
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
            % Constructor
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write(251, 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 252
                error('Could not connect =( ')
            end
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.CurrentFirmwareVersion
                error(['Error: old firmware detected - v' obj.FirmwareVersion '. The current version is: '... 
                    obj.CurrentFirmwareVersion '. Please update the DDS module firmware.'])
            end
            obj.GetParams;
            obj.Initialized = 1;
        end

        function set.Frequency(obj, freq)
            % Set the output waveform frequency
            if obj.Initialized
                obj.Port.write('F', 'uint8', freq*1000, 'uint32');
                obj.confirmTransmission('setting frequency');
            end
            obj.Frequency = freq;
        end

        function set.InputBitRange(obj, newRange)
            % Set the range of input bits, to be mapped to output frequency
            if length(newRange) ~= 2
                error('Error: input bit range must be a vector of 2 numbers - the lower and upper bound (bits)')
            end
            if newRange(1) < 0 || newRange(2) > 65536
                error('Error: input bit range must cannot exceed [0 65536]')
            end
            if newRange(1) > newRange(2)
                error('Error: input bit range vector must increase: [LowBound HighBound]')
            end
            if obj.Initialized
                obj.Port.write('B', 'uint8', newRange, 'uint16');
                obj.confirmTransmission('setting input bit range');
            end
            obj.InputBitRange = newRange;
        end

        function set.OutputMapRange(obj, newRange)
            % Set the range of waveform frequencies to map to the input bits
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
                obj.confirmTransmission('setting output map range');
            end
            obj.OutputMapRange = newRange;
        end

        function set.Amplitude(obj, amp)
            % Set the waveform amplitude (range = 0, 1)
            if obj.Initialized
                if amp < 0 || amp > 1
                    error('Error: amplitude must be in range [0,1]')
                end
                ampValue = floor(amp*10000);
                obj.Port.write('A', 'uint8', ampValue, 'uint16');
                obj.confirmTransmission('setting amplitude');
            end
            obj.Amplitude = amp;
        end

        function set.Waveform(obj,waveform)
            % Set the waveform (sine or triangle)
            waveIndex = find(strcmpi(waveform, obj.ValidWaveforms));
            if isempty(waveIndex)
                error(['Error: ' waveform ' is an invalid waveform name. Valid names are: Sine, Triangle'])
            end
            if obj.Initialized
                obj.Port.write(['W' waveIndex-1], 'uint8');
                obj.confirmTransmission('setting waveform');
            end
            obj.Waveform = waveform;
        end

        function set.MapFcn(obj, functionName)
            % Set the input-bit-to-output-frequency mapping function (linear or exponential)
            fcnIndex = find(strcmpi(functionName, obj.ValidMapFunctions));
            if isempty(fcnIndex)
                error(['Error: ' functionName ' is an invalid map function name. Valid names are: Linear, Exp'])
            end
            if obj.Initialized
                obj.Port.write(['N' fcnIndex-1], 'uint8');
                obj.confirmTransmission('setting map function');
            end
            obj.MapFcn = functionName;
        end

        function map2Freq(obj, value16Bit)
            % Map user-supplied bits to frequency
            if value16Bit < 0 || value16Bit > (2^16)-1
                error('Error: value must be in 16-bit range [0 (2^16)-1]')
            end
            obj.Port.write('M', 'uint8', value16Bit, 'uint16');
            obj.confirmTransmission('setting mapped frequency');
            obj.Port.write('V', 'uint8'); % Request frequency
            obj.Initialized = 0; % Temporarily disable object -> hardware sync
            obj.Frequency = double(obj.Port.read(1, 'uint32'))/1000;
            obj.Initialized = 1;
        end

        function setAmplitudeBits(obj,bits)
            % Set amplitude using bits instead of a normalized range
            obj.Port.write('D', 'uint8', bits, 'uint16');
            obj.confirmTransmission('setting amplitude bits');
        end

        function setAmplitudeZeroCode(obj,bits)
            % Set the bit level at which p2p amplitude is 0V
            obj.Port.write('C', 'uint8', bits, 'uint16');
            obj.confirmTransmission('setting amplitude zero-code');
        end

        function GetParams(obj)
            % Read parameters from device into object fields
            obj.Port.write('Q', 'uint8'); % Request settings
            obj.Frequency = double(obj.Port.read(1, 'uint32'))/1000;
            obj.Amplitude = (double(obj.Port.read(1, 'uint32'))/1000)/10000;
            obj.Waveform = obj.ValidWaveforms{obj.Port.read(1, 'uint8')+1};
            obj.MapFcn = obj.ValidMapFunctions{obj.Port.read(1, 'uint8')+1};
            obj.InputBitRange = double(obj.Port.read(2, 'uint16'));
            obj.OutputMapRange = double(obj.Port.read(2, 'uint32'))/1000;
        end

        function delete(obj)
            % Destructor
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    methods (Access = private)
        function confirmTransmission(obj, opName)
            % Read op confirmation byte, and throw an error if confirm not returned
            
            confirmed = obj.Port.read(1, 'uint8');
            if confirmed == 0
                error(['Error ' opName ': the module denied your request.'])
            elseif confirmed ~= 1
                error(['Error ' opName ': module did not acknowledge the operation.']);
            end
        end
    end
end