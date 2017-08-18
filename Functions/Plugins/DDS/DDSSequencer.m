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
classdef DDSSequencer < handle
    properties
        Port % ArCOM Serial port
        Frequency = 1000; % Last frequency set from plugin object (Hz)
        Amplitude = 1; % Last amplitude set from plugin object, in range [0 1] where 0 = 150mV p2p and 1 = 650mV p2p
        Waveform = 'Sine'; % 'Sine' or 'Triangle'
        Sequence = []; % 1xnSamples List of frequencies (Hz) OR 2xnSamples vector, row1 = frequencies, row2 = onset times
        SamplingRate = 10; % Rate to play frequencies in list (Hz)
        PulseDuration = 0.1; % Pulse duration in sequences with frequency pulses)
        PatternEndTime = 0; % Time when pattern ends. 0 = 1-shot, >0 = loop until PatternEndTime
    end
    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end
    properties (Access = private)
        CurrentFirmwareVersion = 1;
        ValidWaveforms = {'Sine', 'Triangle'};
        Initialized = 0; % Set to 1 after constructor finishes running
    end
    methods
        function obj = DDSSequencer(portString)
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
        function set.SamplingRate(obj, sf)
            if obj.Initialized
                obj.Port.write('S', 'uint8', sf, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting sampling rate. Confirm code not returned.');
                end
            end
            obj.SamplingRate = sf;
            obj.Sequence = obj.Sequence; % Updates pulse timing (if provided) to match new sampling rate.
        end
        function set.PatternEndTime(obj, endTime)
            if obj.Initialized
                obj.Port.write('T', 'uint8', endTime*1000000, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting pattern end time. Confirm code not returned.');
                end
            end
            obj.PatternEndTime = endTime;
        end
        function set.PulseDuration(obj, td)
            if obj.Initialized
                obj.Port.write('D', 'uint8', td*1000000, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting tone duration. Confirm code not returned.');
                end
            end
            obj.PulseDuration = td;
        end
        function set.Sequence(obj, newSequence)
            if ~isempty(newSequence)
                [dataFormat, nSamples] = size(newSequence);
                formattedSequence = newSequence;
                formattedSequence(1,:) = formattedSequence(1,:)*1000;
                if dataFormat > 1
                    formattedSequence(2,:) = round(formattedSequence(2,:)*obj.SamplingRate);
                end
                formattedSequence = formattedSequence(1:end);
                if nSamples > 0
                    if obj.Initialized
                        obj.Port.write(['L' dataFormat-1], 'uint8', nSamples, 'uint16', formattedSequence, 'uint32');
                        Confirmed = obj.Port.read(1, 'uint8');
                        if Confirmed ~= 1
                            error('Error setting sequence. Confirm code not returned.');
                        end
                    end
                else
                    error('Error setting sequence. Sequence must contain at least 1 sample.');
                end
                obj.Sequence = newSequence;
            end
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
        function play(obj)
            if ~isempty(obj.Sequence)
                obj.Port.write('P', 'uint8');
            end
            obj.Initialized = 0; % Disable sync while setting object frequency
            obj.Frequency = 0;
            obj.Initialized = 1;
        end
        function stop(obj)
            obj.Port.write('X', 'uint8');
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    methods (Access = private)
        function GetParams(obj)
            obj.Port.write('Q', 'uint8'); % Request settings
            obj.Frequency = double(obj.Port.read(1, 'uint32'))/1000;
            obj.Amplitude = (double(obj.Port.read(1, 'uint32'))/1000)/10000;
            obj.SamplingRate = double(obj.Port.read(1, 'uint32'));
            obj.Waveform = obj.ValidWaveforms{obj.Port.read(1, 'uint8')+1};
        end
    end
end