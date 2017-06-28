%{
----------------------------------------------------------------------------

This file is part of the Sanworks Pulse Pal repository
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
classdef PulsePalModule < handle
    properties
        Port % ArCOM Serial port
        nChannels % Number of output channels available on connected module
        isBiphasic % See parameter descriptions at: https://sites.google.com/site/pulsepalwiki/parameter-guide
        phase1Voltage
        phase2Voltage
        restingVoltage
        phase1Duration
        interPhaseInterval
        phase2Duration
        interPulseInterval
        burstDuration
        interBurstInterval
        pulseTrainDuration
        pulseTrainDelay
        customTrainID
        customTrainTarget
        customTrainLoop
        rootPath = fileparts(which('PulsePalModule'));
        autoSync = 'on'; % If 'on', changing parameter fields automatically updates PulsePal device. Otherwise, use 'sync' method.
        triggerMode
    end
    
    properties (Access = private)
        currentFirmwareVersion = 1; % Most recent firmware version
        opMenuByte = 213; % Byte code to access op menu
        OS % Host operating system
        guiHandles % Struct with UI handles
        guiAssets % Struct with UI graphics and sounds
        usingOctave % 1 if using Octave, 0 if not
        firmwareVersion % Actual firmware version of connected device 
        cycleFrequency = 10000; % Update rate of Pulse Pal hardware timer
        autoSyncOn = true; % logical version of public property autoSync, to avoid strcmp
        paramNames = {'isBiphasic' 'phase1Voltage' 'phase2Voltage' 'phase1Duration' 'interPhaseInterval' 'phase2Duration'...
            'interPulseInterval' 'burstDuration' 'interBurstInterval' 'pulseTrainDuration' 'pulseTrainDelay'...
            '' '' 'customTrainID' 'customTrainTarget' 'customTrainLoop' 'restingVoltage'};
    end
    
    methods
        function obj = PulsePalModule(portString) % Constructor method, executed when creating the object
            % Determine if using Octave
            if (exist('OCTAVE_VERSION'))
                obj.usingOctave = 1;
            else
                obj.usingOctave = 0;
            end
            if obj.usingOctave
                try
                    pkg load instrument-control
                catch
                    error('Please install the instrument control toolbox first. See http://wiki.octave.org/Instrument_control_package');
                end
                if (exist('serial') ~= 3)
                    error('Serial port communication is necessary for Pulse Pal, but is not supported in Octave on your platform.');
                end
                warning('off', 'Octave:num-to-str');
            end
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write([obj.opMenuByte 72], 'uint8');
            pause(.1);
            HandShakeOkByte = obj.Port.read(1, 'uint8');
            if HandShakeOkByte == 75
                obj.firmwareVersion = obj.Port.read(1, 'uint32');
                if obj.firmwareVersion < obj.currentFirmwareVersion
                    obj.Port.close();
                    error('Error: Old firmware detected. Please update the PulsePalModule firmware and try again.');
                end
            else
                disp('Error: PulsePalModule returned an unexpected handshake signature.')
            end
            obj.Port.write([obj.opMenuByte 95], 'uint8'); % Request number of channels
            obj.nChannels = obj.Port.read(1, 'uint8');
            obj.setDefaultParams;
        end
        
        function trigger(obj, channels, varargin) % Soft-trigger output channels
            if ischar(channels)
                TriggerAddress = bin2dec(channels);
            else
                if nargin > 1
                    channels = [channels cell2mat(varargin)];
                end
                ChannelsBinary = zeros(1,obj.nChannels);
                ChannelsBinary(channels) = 1;
                TriggerAddress = sum(ChannelsBinary .* double(2.^((1:obj.nChannels)-1)));
            end
            obj.Port.write([obj.opMenuByte 77 TriggerAddress], 'uint8');
        end
        
        function abort(obj) % Abort all ongoing playback
            obj.Port.write([obj.opMenuByte 80], 'uint8');
        end
        
        function sync(obj) % If autoSync is off, this will sync all parameters at once.
            obj.syncAllParams;
        end
        
        function setVoltage(obj, channel, voltage)
            % Sets a fixed output channel voltage. Channel = 1-4. Voltage = volts (-10 to +10) 
            obj.checkParamRange(voltage, 'Volts', [-10 10]);
            voltageBits = obj.volts2Bits(voltage);
            obj.Port.write([obj.opMenuByte 79 channel], 'uint8', voltageBits, 'uint16');
        end
        
        function sendCustomPulseTrain(obj, trainID, pulseTimes, voltages) 
            % Sends a custom pulse train to the device. trainId = 1 or 2. pulseTimes = sec. voltages = volts.
            sendCustomTrain(obj, trainID, pulseTimes, voltages);
        end
        
        function sendCustomWaveform(obj, trainID, samplingPeriod, voltages)
            % Sends a custom waveform to the device. trainId = 1 or 2. samplingPeriod = sec. voltages = volts.
            nVoltages = length(voltages);
            if rem(round(samplingPeriod*1000000), 100) > 0
                error('Error: sampling period must be a multiple of 100 microseconds.');
            end
            pulseTimes = 0:samplingPeriod:((nVoltages*samplingPeriod)-(1*samplingPeriod));
            sendCustomTrain(obj, trainID, pulseTimes, voltages);
        end
        
        function setDefaultParams(obj)
            % Loads default parameters and sends them to the device
            autoSyncState = obj.autoSync;
            obj.autoSync = 'off';
            obj.isBiphasic = zeros(1,obj.nChannels);
            obj.phase1Voltage = ones(1,obj.nChannels)*5;
            obj.phase2Voltage = ones(1,obj.nChannels)*-5;
            obj.restingVoltage = zeros(1,obj.nChannels);
            obj.phase1Duration = ones(1,obj.nChannels)*0.001;
            obj.interPhaseInterval = ones(1,obj.nChannels)*0.001;
            obj.phase2Duration = ones(1,obj.nChannels)*0.001;
            obj.interPulseInterval = ones(1,obj.nChannels)*0.009;
            obj.burstDuration = zeros(1,obj.nChannels);
            obj.interBurstInterval = zeros(1,obj.nChannels);
            obj.pulseTrainDuration = ones(1,obj.nChannels);
            obj.pulseTrainDelay = zeros(1,obj.nChannels);
            obj.customTrainID = uint8(zeros(1,obj.nChannels));
            obj.customTrainTarget = uint8(zeros(1,obj.nChannels));
            obj.customTrainLoop = zeros(1,obj.nChannels);
            obj.triggerMode = 0;
            obj.sync;
            if autoSyncState
                obj.autoSync = 'on';
            end
        end
        
        function saveParameters(obj, filename)
            % Saves current parameters to a .mat file.
            if (~strcmp(filename(end-3:end), '.mat'))
                error('The file to save must be a .mat file')
            end
            Parameters = struct;
            Parameters.autoSync = obj.autoSync;
            Parameters.isBiphasic = obj.isBiphasic;
            Parameters.phase1Voltage = obj.phase1Voltage;
            Parameters.phase2Voltage = obj.phase2Voltage;
            Parameters.restingVoltage = obj.restingVoltage;
            Parameters.phase1Duration = obj.phase1Duration;
            Parameters.interPhaseInterval = obj.interPhaseInterval;
            Parameters.phase2Duration = obj.phase2Duration;
            Parameters.interPulseInterval = obj.interPulseInterval;
            Parameters.burstDuration = obj.burstDuration;
            Parameters.interBurstInterval = obj.interBurstInterval;
            Parameters.pulseTrainDuration = obj.pulseTrainDuration;
            Parameters.pulseTrainDelay = obj.pulseTrainDelay;
            Parameters.customTrainID = obj.customTrainID;
            Parameters.customTrainTarget = obj.customTrainTarget;
            Parameters.customTrainLoop = obj.customTrainLoop;
            Parameters.triggerMode = obj.triggerMode;
            save(filename, 'Parameters');
        end
        
        function loadParameters(obj, filename)
            % Loads parameters from a settings file previously saved with
            % the saveParameters method
            S = load(filename);
            Parameters = S.Parameters;
            obj.autoSync = 'off';
            obj.isBiphasic = Parameters.isBiphasic;
            obj.phase1Voltage = Parameters.phase1Voltage;
            obj.phase2Voltage = Parameters.phase2Voltage;
            obj.restingVoltage = Parameters.restingVoltage;
            obj.phase1Duration = Parameters.phase1Duration;
            obj.interPhaseInterval = Parameters.interPhaseInterval;
            obj.phase2Duration = Parameters.phase2Duration;
            obj.interPulseInterval = Parameters.interPulseInterval;
            obj.burstDuration = Parameters.burstDuration;
            obj.interBurstInterval = Parameters.interBurstInterval;
            obj.pulseTrainDuration = Parameters.pulseTrainDuration;
            obj.pulseTrainDelay = Parameters.pulseTrainDelay;
            obj.customTrainID = Parameters.customTrainID;
            obj.customTrainTarget = Parameters.customTrainTarget;
            obj.customTrainLoop = Parameters.customTrainLoop;
            obj.triggerMode = Parameters.triggerMode;
            obj.sync;
            obj.autoSync = Parameters.autoSync;
        end
        
        function set.phase1Voltage(obj, val)
            units = 'Volts'; paramCode = 2;
            obj.setOutputParam(paramCode, val, units);
            obj.phase1Voltage = val;
        end
        
        function set.phase2Voltage(obj, val)
            units = 'Volts'; paramCode = 3;
            obj.setOutputParam(paramCode, val, units);
            obj.phase2Voltage = val;
        end
        
        function set.restingVoltage(obj, val)
            units = 'Volts'; paramCode = 17;
            obj.setOutputParam(paramCode, val, units);
            obj.restingVoltage = val;
        end
        
        function set.phase1Duration(obj, val)
            units = 'Time'; paramCode = 4;
            obj.setOutputParam(paramCode, val, units);
            obj.phase1Duration = val;
        end
        
        function set.interPhaseInterval(obj, val)
            units = 'Time'; paramCode = 5;
            obj.setOutputParam(paramCode, val, units);
            obj.interPhaseInterval = val;
        end
        
        function set.phase2Duration(obj, val)
            units = 'Time'; paramCode = 6;
            obj.setOutputParam(paramCode, val, units);
            obj.phase2Duration = val;
        end
        
        function set.interPulseInterval(obj, val)
            units = 'Time'; paramCode = 7;
            obj.setOutputParam(paramCode, val, units);
            obj.interPulseInterval = val;
        end
        
        function set.burstDuration(obj, val)
            units = 'Time'; paramCode = 8;
            obj.setOutputParam(paramCode, val, units);
            obj.burstDuration = val;
        end
        
        function set.interBurstInterval(obj, val)
            units = 'Time'; paramCode = 9;
            obj.setOutputParam(paramCode, val, units);
            obj.interBurstInterval = val;
        end
        
        function set.pulseTrainDuration(obj, val)
            units = 'Time'; paramCode = 10;
            obj.setOutputParam(paramCode, val, units);
            obj.pulseTrainDuration = val;
        end
        
        function set.pulseTrainDelay(obj, val)
            units = 'Time'; paramCode = 11;
            obj.setOutputParam(paramCode, val, units);
            obj.pulseTrainDelay = val;
        end
        
        function set.customTrainID(obj, val)
            units = 'Byte'; paramCode = 14;
            obj.setOutputParam(paramCode, val, units);
            obj.customTrainID = val;
        end
        
        function set.customTrainTarget(obj, val)
            units = 'Byte'; paramCode = 15;
            if sum(obj.burstDuration(logical(val)) == 0) > 0
                error('Error setting custom train target: a burst duration must be defined before custom timestamps can code for burst onsets.')
            end
            obj.setOutputParam(paramCode, val, units);
            obj.customTrainTarget = val;
        end
        function set.customTrainLoop(obj, val)
            units = 'Byte'; paramCode = 16;
            obj.setOutputParam(paramCode, val, units);
            obj.customTrainLoop = val;
        end
        
        function set.isBiphasic(obj, val)
            units = 'Byte'; paramCode = 1;
            obj.setOutputParam(paramCode, val, units);
            obj.isBiphasic = val;
        end
        
        function set.triggerMode(obj, val)
            obj.Port.write([obj.opMenuByte 91 128], 'uint8', val, 'uint8');
            obj.triggerMode = val;
        end
        
        function set.autoSync(obj, val)
            switch val
                case 'off'
                    obj.autoSyncOn = false;
                case 'on'
                    obj.autoSyncOn = true;
                otherwise
                    error('autoSync must be either ''off'' or ''on''.');
            end
            obj.autoSync = val;
        end
    end
    
    methods (Access = private) 
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
        
        function checkParamRange(obj, param, type, range, varargin)
            RangeLow = range(1);
            RangeHigh = range(2);
            if nargin > 4
                paramCode = varargin{1};
                if paramCode < 128
                    paramCodeString = obj.paramNames{paramCode};
                else
                    paramCodeString = 'triggerMode';
                end
            else
                paramCodeString = 'A parameter';
            end
            if (sum(param < RangeLow) > 0) || (sum(param > RangeHigh) > 0)
                error([paramCodeString ' was out of range: ' num2str(RangeLow) ' to ' num2str(RangeHigh)]);
            end
        end
        
        function bits = volts2Bits(obj, voltage)
            bits = ceil(((voltage+10)/20)*65535);
        end
        
        function volts = bytes2Volts(obj, bytes)
            VoltageBits = typecast(uint8(bytes), 'uint16');
            volts = round((((double(VoltageBits)/65535)*20)-10)*100)/100;
        end
        
        function seconds = bytes2Seconds(obj, Bytes)
            seconds = double(typecast(uint8(Bytes), 'uint32'))/obj.cycleFrequency;
        end
        function confirmWrite(obj)
            confirmed = obj.Port.read(1, 'uint8');
            if confirmed ~= 1
                error('Error: PulsePalModule did not confirm the parameter change.');
            end
        end
        
        function setOutputParam(obj, paramCode, val, units)
            if length(val) == 1
                error(['Error: please specify which channels you want to change ' char(13) ' - P.myParameter(channels) = value.'])
            end
            if length(val) ~= obj.nChannels
                error('Error: there must be exactly one parameter value for each output channel.')
            end
            switch units
                case 'Volts'
                    obj.checkParamRange(val, 'Volts', [-10 10], paramCode);
                    value2send = obj.volts2Bits(val);
                case 'Time'
                    switch paramCode
                        case 4
                            range = [0.0001 3600];
                        case 6
                            range = [0.0001 3600];
                        case 7
                            range = [0.0001 3600];
                        case 10
                            range = [0.0001 3600];
                        otherwise
                            range = [0 3600];
                    end
                    obj.checkParamRange(val, 'Time', range, paramCode);
                    value2send = val*obj.cycleFrequency;
                case 'Byte'
                    switch paramCode
                        case 1
                            range = [0 1];
                        case 12
                            range = [0 1];
                        case 13
                            range = [0 1];
                        case 14
                            range = [0 4];
                        case 15
                            range = [0 1];
                        case 16
                            range = [0 1];
                        case 18
                            range = [0 1];
                    end
                    obj.checkParamRange(val, 'Byte', range, paramCode);
                    value2send = val;
            end
            if obj.autoSyncOn
                if sum(paramCode == [2 3 17]) > 0
                    obj.Port.write([obj.opMenuByte 91 paramCode], 'uint8', value2send, 'uint16');
                elseif sum(paramCode == [4 5 6 7 8 9 10 11]) > 0
                    obj.Port.write([obj.opMenuByte 91 paramCode], 'uint8', value2send, 'uint32');
                else
                    obj.Port.write([obj.opMenuByte 91 paramCode], 'uint8', value2send, 'uint8');
                end
                obj.confirmWrite;
            end
        end
        
        function syncAllParams(obj)
            if obj.autoSyncOn
                error('autoSync is set to ''on''. All parameters are already synchronized.')
            end
            for i = 1:obj.nChannels
                if obj.customTrainTarget(i) == 1
                    BDuration = obj.burstDuration(i);
                    if BDuration == 0
                        error(['Error in output channel ' num2str(i) ': When custom train times target burst onsets, a non-zero burst duration must be defined.'])
                    end
                end
            end
            TimeData = [obj.phase1Duration; obj.interPhaseInterval; obj.phase2Duration;...
                obj.interPulseInterval; obj.burstDuration; obj.interBurstInterval;...
                obj.pulseTrainDuration; obj.pulseTrainDelay]*obj.cycleFrequency;
            TimeData = TimeData';
            VoltageData = [obj.volts2Bits(obj.phase1Voltage); obj.volts2Bits(obj.phase2Voltage); obj.volts2Bits(obj.restingVoltage)];
            VoltageData = VoltageData';
            SingleByteOutputParams = [obj.isBiphasic; obj.customTrainID; obj.customTrainTarget; obj.customTrainLoop];
            SingleByteOutputParams = SingleByteOutputParams';
            SingleByteParams = [SingleByteOutputParams(1:end) obj.triggerMode];
            obj.Port.write([obj.opMenuByte 73], 'uint8', TimeData(1:end), 'uint32', VoltageData(1:end), 'uint16', SingleByteParams, 'uint8');
            obj.confirmWrite;
        end
        
        function sendCustomTrain(obj, trainID, pulseTimes, voltages)
            if length(pulseTimes) ~= length(voltages)
                error('There must be one voltage value (0-255) for every timestamp');
            end
            nPulses = length(pulseTimes);
            if nPulses > 10000
                error('Error: PulsePalModule can only store 10000 pulses per custom pulse train.');
            end
            if sum(sum(rem(round(pulseTimes*1000000), 100))) > 0
                error('Non-zero time values for Pulse Pal must be multiples of 100 microseconds.');
            end
            CandidateTimes = uint32(pulseTimes*obj.cycleFrequency);
            CandidateVoltages = voltages;
            if (sum(CandidateTimes < 0) > 0)
                error('Error: Custom pulse times must be positive');
            end
            if sum(diff(double(CandidateTimes)) < 0) > 0
                error('Error: Custom pulse times must always increase');
            end
            if (CandidateTimes(end) > (3600*obj.cycleFrequency))
                0; error('Error: Custom pulse times must be < 3600 s');
            end
            if (sum(abs(CandidateVoltages) > 10) > 0)
                error('Error: Custom voltage range = -10V to +10V');
            end
            if (length(CandidateVoltages) ~= length(CandidateTimes))
                error('Error: There must be a voltage for every timestamp');
            end
            if (length(unique(CandidateTimes)) ~= length(CandidateTimes))
                error('Error: Duplicate custom pulse times detected');
            end
            TimeOutput = CandidateTimes;
            VoltageOutput = obj.volts2Bits(voltages);
            
            if (trainID > 4) || (trainID < 1)
                error('The first argument must be the stimulus train ID (1-4)')
            end
            obj.Port.write([obj.opMenuByte 75 trainID-1], 'uint8',...
                [nPulses TimeOutput], 'uint32', VoltageOutput, 'uint16');
            obj.confirmWrite;
        end
    end
end