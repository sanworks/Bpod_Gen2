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

% BpodAnalogIn is a class to interface with the Bpod Analog Input Module
% via its USB connection to the PC.
%
% User-configurable device parameters are exposed as class properties. Setting
% the value of a property will trigger its 'set' method to update the device.
%
% Docs:
% https://sanworks.github.io/Bpod_Wiki/module-documentation/analog-input-module/
% Additional documentation of properties and methods is given in-line below.
% 
% Example usage:
% A = BpodAnalogIn('COM3'); % Create an instance of BpodAnalogIn,
%                             connecting to the Analog Input Module on port COM3
% A.scope; % Launch the scope UI to view live signals and adjust thresholds
% A.SamplingRate = 10000; % Set the sampling rate to 10kHz
% A.InputRange{2} = '-5V:5V'; % Set input range of Ch2 to -5V:5V. This will map the bits of 
%                               the ADC to the given range. Use the smallest range
%                               that fits your signal for the highest voltage resolution.
% A.Thresholds(1) = 2.5; % Set event threshold of 1 to 2.5V. Thresholds disable when crossed.
% A.ResetVoltages(1) = 1.5; % Re-enable threshold 1 after voltage falls below 1.5V
% A.SMeventsEnabled(1) = 1; % Configure Ch1 to send threshold crossing events to the state machine
% A.startReportingEvents() % Start sending threshold events to the state machine
% clear A; % clear the object from the workspace, releasing the USB serial port

classdef BpodAnalogIn < handle
    
    properties
        About = struct; % Contains a text string describing each field
        Info = struct; % Contains useful info about the specific hardware detected
        Port % ArCOM wrapper to simplify data transactions on the USB serial port
        Timer % MATLAB timer object
        Status % Struct containing status of ongoing ops (logging, streaming, etc)
        DIOconfig % 1x2 array indicating DIO channel config. 0 = disabled, 1 = output
        nActiveChannels % Number of channels to sample (consecutive, beginning with channel 1)
        SamplingRate % 1Hz-10kHz on v1, 1Hz-50kHz on v2, affects all channels
        InputRange % A cell array of strings indicating voltage range for 12-bit conversion. 
                   % Valid ranges are in Info.InputVoltageRanges (below)
        Thresholds % Threshold (V) for each channel. Analog signal crossing the threshold generates an event.
        ResetVoltages % Voltage must cross ResetValue (V) before another threshold event can occur 
                      % (except in Threshold Mode 1, see above)
        SMeventsEnabled % Logical vector indicating channels that generate events
        Stream2USB % Logical vector indicating channels to stream to USB when streaming is enabled
        Stream2Module % Logical vector indicating channels to stream via Ethernet cable directly to an 
                      % analog output or DDS module (raw data)
        StreamPrefix % Prefix byte sent before each sample when streaming to output module
        nSamplesToLog = Inf; % Number of samples to log to microSD on trigger, 0 = infinite
        USBStreamFile = []; % Full path to file for data acquired with scope() GUI. 
                            % If empty, scope() data is not saved.
    end
    
    properties (Access = private)
        UIhandles % A struct with UI handles
        UIdata % A struct with internal user interface data
        opMenuByte = 213; % Byte code to access op menu
        RangeVoltageSpan % Span of each range in volts
        RangeCodes % Byte codes for voltage ranges in ADC registers
        RangeOffsets % Distance of 0V from bottom of each range
        InputRangeLimits % Table of minimum and maximum voltages for each range
        RangeIndex  % Integer code for voltage range (position in Info.InputVoltageRanges vector above)
        nPhysicalChannels = 8; % Number of physical channels
        Initialized = 0; % Set to 1 after object constructor is done running
        Streaming = 0; % Set to 1 if the oscope display is streaming
        chBits % Bit width of ADC. AIM v1 = 2^13, AIM v2 = 2^16
        USBstream2File = false; % True if data acquired with the scope() GUI is streamed to a file
        USBstreamFile % A memory-mapped .mat file accessed with MATLAB's matfile() function
        USBFile_SamplePos = 1;
        USBFile_EventPos = 1;
    end
    
    methods
        function obj = BpodAnalogIn(portString, varargin)
            % Constructor
            showWarnings = 1;
            obj.Info.FirmwareVersion = NaN;
            obj.Info.HardwareVersion = NaN;
            obj.Info.InputVoltageRanges = NaN;
            usePsychToolbox = [];
            if nargin > 1
                op = varargin{1};
                switch op
                    case 'nowarnings'
                        showWarnings = 0;
                    case 'psychtoolbox'
                        usePsychToolbox = 'psychtoolbox';
                end
            end
            obj.Port = ArCOMObject_Bpod(portString, 12000000, usePsychToolbox, [], 1000000, 1000000);
            obj.Port.write([obj.opMenuByte 'O'], 'uint8');
            handShakeOkByte = obj.Port.read(1, 'uint8');
            if handShakeOkByte == 161 % Correct handshake response
                obj.Info.FirmwareVersion = obj.Port.read(1, 'uint32');
                try
                    addpath(fullfile(fileparts(which('Bpod')), 'Functions', 'Internal Functions'));
                    currentFirmware = CurrentFirmwareList;
                    latestFirmware = currentFirmware.AnalogIn;
                catch
                    % Stand-alone configuration (Bpod not installed); assume latest firmware
                    latestFirmware = obj.Info.FirmwareVersion;
                end
                if obj.Info.FirmwareVersion < latestFirmware
                    if showWarnings == 1
                        disp('*********************************************************************');
                        disp(['Warning: Old firmware detected: v' num2str(obj.Info.FirmwareVersion) ...
                            '. The current version is: v' num2str(latestFirmware) char(13)...
                            'Please update using the firmware update tool: LoadBpodFirmware().'])
                        disp('*********************************************************************');
                    end
                elseif obj.Info.FirmwareVersion > latestFirmware
                    error(['Analog Input Module with future firmware found. ' ...
                           'Please update your Bpod software from the Bpod_Gen2 repository.']);
                end
                obj.Info.HardwareVersion = 1;
                if obj.Info.FirmwareVersion > 4
                    obj.Port.write([obj.opMenuByte 'H'], 'uint8');
                    obj.Info.HardwareVersion = obj.Port.read(1, 'uint8');
                    if isempty(usePsychToolbox)
                        % Throttle USB if module v2 + MATLAB serial interface
                        obj.Port.write([obj.opMenuByte 't' 1], 'uint8'); 
                    else
                        obj.Port.write([obj.opMenuByte 't' 0], 'uint8');
                    end
                    % If HW version 2, restart serial port with Teensy 4's correct baud rate --> buffer sizes
                    if obj.Info.HardwareVersion == 2
                        obj.Port = [];
                        pause(.2);
                        obj.Port = ArCOMObject_Bpod(portString, 480000000, usePsychToolbox);
                    end
                end
                switch obj.Info.HardwareVersion
                    case 1
                        obj.chBits = 2^13;
                        obj.Info.SamplingRateRange = [1 10000];
                        obj.Info.InputVoltageRanges = {'-10V:10V', '-5V:5V', '-2.5V:2.5V','0V:10V'};
                        obj.RangeCodes = [0 1 2 3];
                        obj.RangeVoltageSpan = [20 10 5 10];
                        obj.RangeOffsets = [10 5 2.5 0];
                        obj.InputRangeLimits = [-10 10; -5 5; -2.5 2.5; 0 10];
                        obj.RangeIndex = ones(1,obj.nPhysicalChannels);
                    case 2
                        obj.chBits = 2^16;
                        obj.Info.SamplingRateRange = [1 50000];
                        obj.Info.InputVoltageRanges = {'-2.5V:2.5V', '-5V:5V', '-6.25V:6.25V', '-10V:10V',... 
                                                       '-12.5V:12.5V', '0V:5V', '0V:10V', '0V:12.5V'};
                        obj.RangeCodes = [0 1 2 3 4 5 6 7];
                        obj.RangeVoltageSpan = [5 10 12.5 20 25 5 10 12.5];
                        obj.RangeOffsets = [2.5 5 6.25 10 12.5 0 0 0];
                        obj.InputRangeLimits = [-2.5 2.5; -5 5; -6.25 6.25; -10 10; -12.5 12.5; 0 5; 0 10; 0 12.5];
                        obj.RangeIndex = ones(1,obj.nPhysicalChannels)*4;
                end
            else
                error(['Error: The serial port (' portString ') returned an unexpected handshake signature.'])
            end
            % Set defaults (also set in parallel on device)
            obj.Initialized = 1;
            obj.SamplingRate = 1000;
            obj.Status = struct;
            obj.Status.Logging = 0;
            obj.Status.EventReporting = 0;
            obj.Status.USBStreamEnabled = 0;
            obj.Status.ModuleStreamEnabled = 0;
            obj.nActiveChannels = obj.nPhysicalChannels;
            obj.Thresholds = ones(1,obj.nPhysicalChannels)*10; % Initialized to max voltage of default range
            obj.ResetVoltages = ones(1,obj.nPhysicalChannels)*-10;
            obj.SMeventsEnabled = zeros(1,obj.nPhysicalChannels);
            obj.Stream2USB = zeros(1,obj.nPhysicalChannels);
            obj.Stream2Module = zeros(1,obj.nPhysicalChannels);
            obj.StreamPrefix = 'R';
            obj.InputRange  = repmat(obj.Info.InputVoltageRanges(obj.RangeIndex(1)), 1, obj.nPhysicalChannels);
            if obj.Info.HardwareVersion == 1 % HW v1 has DIO Ch1 set output high by default, 
                                             % as a voltage source for resistive sensors
                obj.DIOconfig = [1 0]; % 0 = disabled, 1 = output
                obj.setDIO(1, 1);
            else
                obj.DIOconfig = [0 0]; % 0 = disabled, 1 = output
            end
            
            obj.About.Port = 'ArCOM USB serial port wrapper. See https://github.com/sanworks/ArCOM';
            obj.About.GUIhandles = 'A struct containing handles of the UI';
            obj.About.Status = 'A struct containing process status: logging, streaming, returning threshold events';
            obj.About.SamplingRate = 'Sampling rate for all channels (in Hz)';
            obj.About.InputRange = 'Voltage range mapped to converter bits. Valid ranges are in .Info.InputVoltageRanges';
            obj.About.nActiveChannels = '#channels to read, beginning with channel 1. Fewer channels -> faster sampling.';
            obj.About.Thresholds = 'Threshold, in volts, generates a Bpod behavioral event when crossed.';
            obj.About.ResetVoltages = 'Reset voltages for each channel. Voltage below this value re-enables the threshold.';
            obj.About.SMeventsEnabled = 'Logical vector indicating channels that generate threshold crossing events';
            obj.About.Stream2USB = 'Logical vector indicating which channels stream raw data to USB.';
            obj.About.Stream2Module = 'Logical vector indicating which channels stream raw data to output module.';
            obj.About.nSamplesToLog = 'Number of samples to log to microSD (instead of USB streaming). 0 = Infinite.';
            obj.About.METHODS = 'type methods(myObject) at the command line to see a list of valid methods.';            

        end
        function set.nSamplesToLog(obj, nSamples)
            % Set the number of samples to log (0 = until manually stopped)
            if obj.Initialized
                nSamples2Send = nSamples;
                if nSamples == Inf
                    nSamples2Send = 0;
                end
                % Used to acquire a fixed number of samples
                obj.Port.write([obj.opMenuByte 'W'], 'uint8', nSamples2Send, 'uint32');
                obj.confirmTransmission('nSamplesToLog');
                if nSamples == 0
                    nSamples = Inf;
                end
            end
            obj.nSamplesToLog = nSamples;
        end
        
        function set.SamplingRate(obj, sf)
            % Set the sampling rate (affects all channels)
            if obj.Initialized
                if obj.USBstream2File
                    error('The analog input module sampling rate cannot be changed while streaming to a file.');
                end
                if sf < obj.Info.SamplingRateRange(1) || sf > obj.Info.SamplingRateRange(2)
                    error(['Error setting sampling rate: valid rates are in range: ['... 
                           num2str(obj.Info.SamplingRateRange) '] Hz'])
                end
                obj.Port.write([obj.opMenuByte 'F'], 'uint8', sf,'uint32');
                obj.confirmTransmission('sampling rate');
            end
            obj.SamplingRate = sf;
        end
        
        function set.StreamPrefix(obj, prefix)
            % Set the module-to-module output data stream prefix, a command byte
            % sent immediately prior to each sample
            if obj.Initialized
                if length(prefix) > 1
                    error(['Error setting prefix: the prefix must be a single byte.'])
                end
                obj.Port.write([obj.opMenuByte 'P' prefix], 'uint8');
                obj.confirmTransmission('stream prefix');
            end
            obj.StreamPrefix = prefix;
        end
        
        function set.USBStreamFile(obj, fileName)
            % Set the data file for logging while USB streaming
            obj.USBstream2File = false;
            if isempty(fileName)
                obj.USBStreamFile = [];
                obj.USBstreamFile = [];
            else
                FP = fileparts(fileName);
                if isempty(FP)
                    error(['Error setting AnalogInput data file: ' fileName... 
                           ' is not a valid filename. The filename must be the full path of the target data file.'])
                end
                if exist(FP) ~= 7
                    error(['Error setting AnalogInput data file: ' FP ' is not a valid folder.'])
                end
                if exist(fileName) == 2
                    error(['Error setting AnalogInput data file: ' fileName... 
                           ' already exists. Please manually delete the file or change the target filename before acquiring.'])
                end
                obj.USBFile_SamplePos = 1;
                obj.USBFile_EventPos = 1;
                obj.USBstream2File = true;
                obj.USBstreamFile = matfile(fileName,'Writable',true);
                obj.USBstreamFile.Samples = [];
                obj.USBstreamFile.SyncEvents = []; % Data of each sync event (range = 0-255)
                obj.USBstreamFile.SyncEventTimes = []; % Indexes of the sample during which each sync event was captured
                obj.USBStreamFile = fileName;
            end
        end

        function set.DIOconfig(obj, config)
            if length(config) ~= 2 || max(config) > 1 || min(config) < 0
                error('DIO Config must be a 1x2 array of values encoded as: 0 = disabled, 1 = output')
            end
            obj.Port.write([obj.opMenuByte '-' config], 'uint8');
            obj.confirmTransmission('DIOconfig');
            obj.DIOconfig = config;
        end
        
        function set.nActiveChannels(obj, nChannels)
            % Set number of active channels. Inactive channels are not measured or acquired.
            if obj.Initialized
                if obj.USBstream2File
                    error('The analog input module active channel set cannot be changed while streaming to a file.');
                end
                if nChannels < 1 || nChannels > obj.nPhysicalChannels
                    error(['Error setting active channel count: nChannels must be in the range 1:'... 
                           num2str(obj.nPhysicalChannels)]);
                end
                obj.Port.write([obj.opMenuByte 'A' nChannels], 'uint8');
                obj.confirmTransmission('active channels');
            end
            obj.nActiveChannels = nChannels;
        end
        
        function set.InputRange(obj, value)
            % Set input range. ADC bits are mapped to the selected range. Use the
            % smallest range that fits your signal for the best voltage precision.
            if obj.Initialized
                if obj.USBstream2File
                    error('Error: The analog input module voltage range cannot be changed while streaming to a file.');
                end
                inputRangeIndex = ones(1,obj.nPhysicalChannels);
                inputRangeIndexCode = ones(1, obj.nPhysicalChannels);
                for i = 1:obj.nPhysicalChannels
                    rangeString = value{i};
                    rangeIndex = find(strcmp(rangeString, obj.Info.InputVoltageRanges),1);
                    if isempty(rangeIndex)
                        rangeListString = [];
                        for i = 1:length(obj.Info.InputVoltageRanges)
                            rangeListString = [rangeListString char(10) obj.Info.InputVoltageRanges{i}];
                        end
                        error(['Invalid range specified: ' rangeString '. Valid ranges are: ' rangeListString]);
                    end
                    inputRangeIndex(i) = rangeIndex;
                    inputRangeIndexCode(i) = obj.RangeCodes(rangeIndex);
                end
                obj.Port.write([obj.opMenuByte 'R' inputRangeIndexCode], 'uint8');
                obj.confirmTransmission('voltage range');
                oldRangeIndex = obj.RangeIndex;
                obj.RangeIndex = inputRangeIndex;
                % Set thresholds and reset values (expressed in voltages) to values in new range.
                % Thresholds that are out of range are set to maximum range.
                [ydimThresh,~] = size(obj.Thresholds);
                [ydimReset,~] = size(obj.ResetVoltages);
                newThresholds = obj.Thresholds;
                newResets = obj.ResetVoltages;
                for i = 1:obj.nPhysicalChannels
                    thisRangeMin = obj.InputRangeLimits(obj.RangeIndex(i),1);
                    thisRangeMax = obj.InputRangeLimits(obj.RangeIndex(i),2);
                    for j = 1:ydimThresh
                        if newThresholds(j,i) < thisRangeMin
                            newThresholds(j,i) = thisRangeMin;
                        elseif newThresholds(j,i) > thisRangeMax
                            newThresholds(j,i) = thisRangeMax;
                        end
                        if obj.Thresholds(j,i) == obj.InputRangeLimits(oldRangeIndex(i), 2)
                            newThresholds(j,i) = thisRangeMax;
                        end
                    end
                    for j = 1:ydimReset
                        if newResets(j,i) < thisRangeMin
                            newResets(j,i) = thisRangeMin;
                        elseif newResets(j,i) > thisRangeMax
                            newResets(j,i) = thisRangeMax;
                        end
                        if obj.ResetVoltages(j,i) == obj.InputRangeLimits(oldRangeIndex(i), 1)
                            newResets(j,i) = thisRangeMin;
                        end
                    end
                end
                ranges = obj.RangeIndex;
                if obj.Info.FirmwareVersion > 5
                    ranges = [ranges obj.RangeIndex];
                end
                obj.InputRange = value;
                % Reset and threshold must be set simultanesously, since they
                % were changed simultaneously. Instead of calling
                % set.Thresholds, and set.ResetVoltages, the next 4 lines do both at once.
                newThresholdVector = reshape(newThresholds',1,[]);
                if obj.Info.FirmwareVersion > 5 && ydimThresh == 1
                    newThresholdVector = [newThresholdVector obj.InputRangeLimits(obj.RangeIndex,2)'];
                end
                thresholdBits = obj.Volts2Bits(newThresholdVector, ranges);
                newResetsVector = reshape(newResets',1,[]);
                if obj.Info.FirmwareVersion > 5 && ydimReset == 1
                    newResetsVector = [newResetsVector obj.InputRangeLimits(obj.RangeIndex,1)'];
                end
                resetValueBits = obj.Volts2Bits(newResetsVector, ranges);
                obj.Port.write([obj.opMenuByte 'T'], 'uint8', [thresholdBits resetValueBits], 'uint16');
                obj.confirmTransmission('thresholds');
                obj.Initialized = 0; % Disable updating to change the object
                obj.Thresholds = newThresholds;
                obj.ResetVoltages = newResets;
                obj.Initialized = 1;
            else
                obj.InputRange = value;
            end
            
        end
        
        function set.Thresholds(obj, thersholdValues)
            % Set voltage thresholds for Bpod behavioral event generation.
            % thersholdValues argument can be a 1x8 or 2x8 vector of
            % voltages to configure thresholds 1 and 2 for each of the 8 channels. 
            % If a 1x8 is provided, threshold 2 is automatically set to max range.
            if obj.Initialized         
                [ydimThresh,xdimThresh] = size(thersholdValues);
                newThresholds = reshape(thersholdValues',1,[]);
                [ydimReset,xdimReset] = size(obj.ResetVoltages);
                newResetVoltages = reshape(obj.ResetVoltages',1,[]);
                if isempty(newResetVoltages)
                    if obj.Info.FirmwareVersion > 5
                        newResetVoltages = ones(1,obj.nPhysicalChannels*2)*-10;
                    else
                        newResetVoltages = ones(1,obj.nPhysicalChannels)*-10;
                    end
                end
                if ydimThresh == 1 && obj.Info.FirmwareVersion > 5
                    newThresholds = [newThresholds obj.InputRangeLimits(obj.RangeIndex,2)'];
                elseif ydimThresh > 2
                    error('Only 2 thresholds can be configured per channel')
                end
                if ydimReset == 1 && obj.Info.FirmwareVersion > 5
                    newResetVoltages = [newResetVoltages obj.InputRangeLimits(obj.RangeIndex,1)'];
                end
                % Ensure that threshold is in currently configured range
                for i = 1:obj.nPhysicalChannels
                    % Check threshold 1 for each channel
                    if newThresholds(i) < obj.InputRangeLimits(obj.RangeIndex(i),1) || newThresholds(i) >... 
                            obj.InputRangeLimits(obj.RangeIndex(i),2)
                        error(['Error setting threshold: a threshold for channel ' num2str(i)... 
                               ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                    end
                    if obj.Info.FirmwareVersion > 5
                        % Check threshold 2 for each channel
                        if newThresholds(i+obj.nPhysicalChannels) < obj.InputRangeLimits(obj.RangeIndex(i),1)... 
                                || newThresholds(i+obj.nPhysicalChannels) > obj.InputRangeLimits(obj.RangeIndex(i),2)
                            error(['Error setting threshold: a threshold for channel ' num2str(i)... 
                                   ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                        end
                    end
                end
                
                %Convert thresholds to bits according to voltage range.
                ranges = obj.RangeIndex;
                if obj.Info.FirmwareVersion > 5
                    ranges = [ranges obj.RangeIndex];
                end
                resetValueBits = obj.Volts2Bits(newResetVoltages, ranges);
                thresholdBits = obj.Volts2Bits(newThresholds, ranges);
                obj.Port.write([obj.opMenuByte 'T'], 'uint8', [thresholdBits resetValueBits], 'uint16');
                obj.confirmTransmission('thresholds');
            end
            obj.Thresholds = thersholdValues;
        end
        
        function set.ResetVoltages(obj, resetValues)
            % Set reset voltage to re-enable thresholds, which are disabled after a
            % threshold crossing event.
            % The resetValues argument can be a 1x8 or 2x8 vector of
            % voltages to configure reset voltages 1 and 2 for each of the 8 channels. 
            % If a 1x8 is provided, reset voltage 2 is automatically set to min range.
            if obj.Initialized
                [ydimReset,xdimReset] = size(resetValues);
                newResetVoltages = reshape(resetValues',1,[]);
                [ydimThresh,xdimThresh] = size(obj.Thresholds);
                newThresholds = reshape(obj.Thresholds',1,[]);
                if isempty(newThresholds)
                    if obj.Info.FirmwareVersion > 5
                        newThresholds = ones(1,obj.nPhysicalChannels*2)*10;
                    else
                        newThresholds = ones(1,obj.nPhysicalChannels)*10;
                    end
                end
                if ydimReset == 1 && obj.Info.FirmwareVersion > 5
                    newResetVoltages = [newResetVoltages obj.InputRangeLimits(obj.RangeIndex,1)'];
                elseif ydimReset > 2
                    error('Only 2 threshold reset voltages can be configured per channel')
                end
                if ydimThresh == 1 && obj.Info.FirmwareVersion > 5
                    newThresholds = [newThresholds obj.InputRangeLimits(obj.RangeIndex,2)'];
                end
                % Ensure that new reset voltages are in currently configured range
                for i = 1:obj.nPhysicalChannels
                    % Check threshold 1 for each channel
                    if newResetVoltages(i) < obj.InputRangeLimits(obj.RangeIndex(i),1) || newResetVoltages(i) >... 
                            obj.InputRangeLimits(obj.RangeIndex(i),2)
                        error(['Error setting reset voltage: a reset voltage for channel ' num2str(i)... 
                               ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                    end
                    if obj.Info.FirmwareVersion > 5
                        % Check threshold 2 for each channel
                        if newResetVoltages(i+obj.nPhysicalChannels) < obj.InputRangeLimits(obj.RangeIndex(i),1) ||... 
                                newResetVoltages(i+obj.nPhysicalChannels) > obj.InputRangeLimits(obj.RangeIndex(i),2)
                            error(['Error setting reset voltage: a reset voltage for channel ' num2str(i)... 
                                   ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                        end
                    end
                end
                ranges = obj.RangeIndex;
                if obj.Info.FirmwareVersion > 5
                    ranges = [ranges obj.RangeIndex];
                end
                %Convert thresholds to bits according to voltage range.
                resetValueBits = obj.Volts2Bits(newResetVoltages, ranges);
                thresholdBits = obj.Volts2Bits(newThresholds, ranges);
                obj.Port.write([obj.opMenuByte 'T'], 'uint8', [thresholdBits resetValueBits], 'uint16');
                obj.confirmTransmission('reset values');
            end
            obj.ResetVoltages = resetValues;
        end
        
        function set.SMeventsEnabled(obj, value)
            % Set the list of channels that return threshold crossing events.
            if obj.Initialized
                if ~(length(value) == obj.nPhysicalChannels && sum((value == 0) | (value == 1)) == obj.nPhysicalChannels)
                    error('Error setting events enabled: enabled state must be 0 or 1')
                end
                obj.Port.write([obj.opMenuByte 'K' value], 'uint8');
                obj.confirmTransmission('events enabled');
            end
            obj.SMeventsEnabled = value;
        end
        
        function startModuleStream(obj)
            % Start streaming analog data from the 'Output Stream' Ethernet jack.
            % This can be sent directly to the analog output or DDS modules (using custom firmware).
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 1 1], 'uint8');
            end
            obj.confirmTransmission('Module stream');
            obj.Status.ModuleStreamEnabled = 1;
        end
        
        function stopModuleStream(obj)
            % Stop streaming data from the 'Output Stream' Ethernet jack.
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 1 0], 'uint8');
                obj.confirmTransmission('Module stream');
            end
            obj.Status.ModuleStreamEnabled = 0;
        end
        
        function startUSBStream(obj)
            % Start streaming analog data to the PC via USB
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 0 1], 'uint8');
                %obj.confirmTransmission('USB stream');
            end
            obj.Status.USBStreamEnabled = 1;
        end
        
        function stopUSBStream(obj)
            % Stop streaming analog data to the PC via USB
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 0 0], 'uint8');
                obj.USBStreamFile = []; % Stop writing to the current file
                % Do not confirm; data bytes in buffer may be expected by
                % another application
            end
            obj.Status.USBStreamEnabled = 0;
        end
        
        function startReportingEvents(obj)
            % Start sending threshold crossing events to the state machine.
            % Only events from channels selected in SMeventsEnabled will be sent.
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'E' 1 1], 'uint8');
                obj.confirmTransmission('event reporting');
            end
            obj.Status.EventReporting = 1;
        end
        
        function stopReportingEvents(obj)
            % Stop sending threshold crossing events to the state machine.
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'E' 1 0], 'uint8');
                obj.confirmTransmission('event reporting');
            end
            obj.Status.EventReporting = 0;
        end
        
        function startLogging(obj)
            % Start logging analog data to the microSD card
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'L' 1], 'uint8');
                obj.confirmTransmission('start logging');
                obj.Status.Logging = 1;
            end
        end
        
        function stopLogging(obj)
            % Stop logging analog data to the microSD card
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'L' 0], 'uint8');
                obj.confirmTransmission('stop logging');
                obj.Status.Logging = 0;
            end
        end
        
        function set.Stream2USB(obj, value)
            % Set the list of channels that send data during USB streaming.
            if obj.Initialized
                if ~(length(value) == obj.nPhysicalChannels && sum((value == 0) | (value == 1)) == obj.nPhysicalChannels)
                    error('Error setting Stream2USB channels: value for each channel must be 0 or 1')
                end
                stream2Module = obj.Stream2Module;
                if isempty(stream2Module) % This only occurs in the constructor
                    stream2Module = zeros(1, obj.nPhysicalChannels);
                end
                obj.Port.write([obj.opMenuByte 'C' value stream2Module], 'uint8');
                obj.confirmTransmission('stream to USB');
            end
            obj.Stream2USB = value;
        end
        
        function set.Stream2Module(obj, value)
            % Set the list of channels that send data during direct module-to-module streaming.
            if obj.Initialized
                if ~(length(value) == obj.nPhysicalChannels && sum((value == 0) | (value == 1)) == obj.nPhysicalChannels)
                    error('Error setting Stream2USB channels: value for each channel must be 0 or 1')
                end
                Stream2USB = obj.Stream2USB;
                if isempty(Stream2USB) % This only occurs in the constructor
                    Stream2USB = zeros(1, obj.nPhysicalChannels);
                end
                obj.Port.write([obj.opMenuByte 'C' Stream2USB value], 'uint8');
                obj.confirmTransmission('stream to Module');
            end
            obj.Stream2Module = value;
        end

        function fv = getFirmwareVersion(obj)
            % Return the detected firmware version
            fv = obj.Info.FirmwareVersion;
        end

        function voltage = readChannel(obj, chan)
            % readChannel() reads the current voltage from a single channel
            % Arguments:
            % chan: The channel to read
            % Returns:
            % voltage: The voltage measured from the selected channel

            usbStreamConfig = obj.Stream2USB;
            newStreamConfig = zeros(1,length(usbStreamConfig));
            newStreamConfig(chan) = 1;
            obj.Stream2USB = newStreamConfig;
            obj.startUSBStream;
            while obj.Port.bytesAvailable < 4
                pause(.001);
            end
            obj.stopUSBStream;
            msg = obj.Port.read(2, 'uint16');
            pause(.1); % Pause to ensure that streaming has stopped
            obj.Port.flush;
            thisMultiplier = obj.RangeVoltageSpan(obj.RangeIndex(chan));
            thisOffset = obj.RangeOffsets(obj.RangeIndex(chan));
            voltage = ((double(msg(2))/obj.chBits)*thisMultiplier)-thisOffset;
            obj.Stream2USB = usbStreamConfig;
        end

        function data = getData(obj)
            % getData() returns new data acquired to the microSD card between calls to 
            % startLogging() and stopLogging(). Start and stop commands can
            % also be sent from the state machine: {'AnalogIn1', ['L' 1]}
            % to start and {'AnalogIn1', ['L' 0]} to stop. 
            % microSD logging is implemented to support legacy code. For
            % continuous data logging during the session, use the scope()
            % GUI, e.g. \Examples\Protocols\Analog_Input\Light2AFC_AnalogStreaming

            obj.Port.flush;
            obj.Port.write([obj.opMenuByte 'D'], 'uint8');
            nSamples = double(obj.Port.read(1, 'uint32'));
            nValues = double(obj.nActiveChannels*nSamples);
            rawData = zeros(1,nValues, 'uint16');
            maxValuesToRead = 100000;
            nReads = floor(nValues/maxValuesToRead);
            partialReadLength = nValues-(nReads*maxValuesToRead);
            pos = 1;
            for i = 1:nReads
                rawData(pos:pos+maxValuesToRead-1) = obj.Port.read(maxValuesToRead, 'uint16');
                pos = pos + maxValuesToRead;
            end
            if partialReadLength > 0
                rawData(pos:pos+partialReadLength-1) = obj.Port.read(partialReadLength, 'uint16');
            end

            data = struct;
            data.y = zeros(obj.nActiveChannels, nSamples);
            reshapedRawData = reshape(rawData, obj.nActiveChannels, nSamples);
            for i = 1:obj.nActiveChannels
                thisMultiplier = obj.RangeVoltageSpan(obj.RangeIndex(i));
                thisOffset = obj.RangeOffsets(obj.RangeIndex(i));
                data.y(i,:) = ((double(reshapedRawData(i,:))/obj.chBits)*thisMultiplier)-thisOffset;
            end
            period = 1/obj.SamplingRate;
            data.x = 0:period:(period*double(nSamples)-period);
        end

        function setDIO(obj, chan, value)
            if ~ismember(chan, [1 2])
                error('DIO Channel must be either 1 or 2')
            end
            if ~ismember(value, [0 1])
                error('DIO value must be either 0 or 1')
            end
            if obj.DIOconfig(chan) ~= 1
                error('To use setDIO, target DIO channel must be configured as output.')
            end
            obj.Port.write([obj.opMenuByte '=' chan-1 value], 'uint8');
        end
        
        function setZero(obj)
            % To compensate for the ADC zero-code offset, attach Ch1 to its
            % ground and run setZero. The offset is stored to the device in
            % non-volatile memory, so setZero only needs to be run once. 
            % Note: All Sanworks-built modules are zeroed during production.
            obj.Port.write([obj.opMenuByte 'Z'], 'uint8');
        end
        
        function Scope(obj)
            % Alias to make the scope() command case insensitive
            obj.scope;
        end
        
        function scope(obj)
            % Launch an oscilloscope-style GUI to view live analog data. 
            % The GUI also allows the user to configure thresholds, set the data
            % file, and configure the voltage range of each channel.
            % Live data display and storage is driven by a timer callback,
            % so the GUI can run in parallel with an experimental session,
            % e.g. \Bpod_Gen2\Examples\Protocols\Analog_Input\Light2AFC_AnalogStreaming
            if isfield(obj.UIhandles, 'OscopeFig')
                if ~isempty(obj.UIhandles.OscopeFig)
                    figure(obj.UIhandles.OscopeFig);
                    return
                end
            end
            obj.UIhandles.nXDivisions = 12;
            obj.UIhandles.nYDivisions = 8;
            obj.UIdata.VoltDivPos = 11;
            obj.UIdata.TimeDivPos = 5;
            obj.UIdata.VoltDivValues = [0.002 0.005 0.01 0.02 0.05 0.1 0.2 0.5 1 2 5];
            obj.UIdata.TimeDivValues = [0.01 0.02 0.05 0.1 0.2 0.5 1 2];
            obj.UIdata.nDisplaySamples = obj.SamplingRate * obj.UIdata.TimeDivValues(obj.UIdata.TimeDivPos) *... 
                                         obj.UIhandles.nXDivisions;
            obj.UIdata.SweepPos = 1;
            if isunix && ~ismac
                titleFontSize = 16;
                scaleFontSize = 14;
                subTitleFontSize = 12;
                lineEdge = 0.25;
                figHeight = 470;
                dropFontSize = 8;
            else
                titleFontSize = 18;
                scaleFontSize = 18;
                subTitleFontSize = 16;
                lineEdge = 0;
                figHeight = 500;
                dropFontSize = 10;
            end
            oscBGColor = [0.55 0.55 0.55];
            lineColors = {[1 1 0], [0 1 1], [1 0.5 0], [0 1 0], [1 .3 .3], [.6 .2 1], [.3 .3 1], [1 0 1]};
            resetLineColors = cell(1,obj.nPhysicalChannels);
            for i = 1:obj.nPhysicalChannels
                resetLineColors{i} = lineColors{i}*0.5;
            end
            obj.UIhandles.OscopeFig = figure('Name','Scope',...
                'NumberTitle','off',...
                'MenuBar','none',...
                'Color',oscBGColor,...
                'Position',[100,100,1024,figHeight],...
                'CloseRequestFcn',@(h,e)obj.endAcq());
            obj.UIhandles.Plot = axes('units','pixels', 'position',[10 10 640 480], ...
                'box', 'off', 'tickdir', 'out', 'Color', [0.1 0.1 0.1]);
            set(gca, 'xlim', [0 obj.UIhandles.nXDivisions], 'ylim', [-0.4 obj.UIhandles.nYDivisions], 'ytick', [], 'xtick', []);
            interval = obj.UIhandles.nXDivisions/obj.UIdata.nDisplaySamples;
            obj.UIdata.Xdata = 0:interval:obj.UIhandles.nXDivisions-interval;
            obj.UIdata.Ydata = nan(obj.nPhysicalChannels,obj.UIdata.nDisplaySamples);
            for i = 1:obj.UIhandles.nYDivisions-1
                obj.UIhandles.GridXLines(i) = line([0,obj.UIhandles.nXDivisions],[i,i], 'Color', [.3 .3 .3], 'LineStyle',':');
                if i == floor(obj.UIhandles.nYDivisions/2)
                    set(obj.UIhandles.GridXLines(i), 'Color', [.6 .6 .6]);
                end
            end
            for i = 1:obj.UIhandles.nXDivisions-1
                obj.UIhandles.GridYLines(i) = line([i,i],[0,obj.UIhandles.nYDivisions], 'Color', [.3 .3 .3], 'LineStyle',':');
                if i == floor(obj.UIhandles.nXDivisions/2)
                    set(obj.UIhandles.GridYLines(i), 'Color', [.6 .6 .6]);
                end
            end
            for i = 1:obj.nPhysicalChannels
                obj.UIhandles.OscopeDataLine(i) = line([obj.UIdata.Xdata,obj.UIdata.Xdata],...
                                                       [obj.UIdata.Ydata(i,:),obj.UIdata.Ydata(i,:)], 'Color', lineColors{i});
            end
            currentVoltDivValue = obj.UIdata.VoltDivValues(obj.UIdata.VoltDivPos);
            maxVolts = currentVoltDivValue*(obj.UIhandles.nYDivisions); HalfMax = maxVolts/2;
            visibilityVec = {'Off', 'On'};
            for i = 1:obj.nPhysicalChannels
                threshY = ((obj.Thresholds(1,i)+HalfMax)/maxVolts)*obj.UIhandles.nYDivisions;
                obj.UIhandles.ThresholdLine(i) = line([0 obj.UIhandles.nXDivisions],[threshY,threshY],...
                    'Color', lineColors{i}, 'LineStyle', ':', 'Visible', visibilityVec{obj.SMeventsEnabled(i)+1});
                resetY = ((obj.ResetVoltages(1,i)+HalfMax)/maxVolts)*obj.UIhandles.nYDivisions;
                obj.UIhandles.ResetLine(i) = line([0 obj.UIhandles.nXDivisions],[resetY,resetY],...
                    'Color', resetLineColors{i}, 'LineStyle', ':', 'Visible', visibilityVec{obj.SMeventsEnabled(i)+1});
            end
            
            
            obj.UIhandles.MaskLine = line([lineEdge,obj.UIhandles.nXDivisions-lineEdge],[-0.2,-0.2],... 
                                     'Color', [.2 .2 .2], 'LineWidth', 20);
            obj.UIhandles.VDivText = text(0.2,-0.2, 'V/div: 5.0', 'Color', 'yellow', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.TimeText = text(9.5,-0.2, 'Time 200.0ms', 'Color', 'yellow', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.StatText = text(0.2,7.7, 'Stopped', 'Color', 'red', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.RecStatText = text(10.1,7.7, '', 'Color', 'red', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.RunButton = uicontrol('Style', 'pushbutton', 'String', 'RUN', 'Position', [895 390 120 95],...
                'Callback',@(h,e)obj.scope_StartStop(), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Start/Stop Data Stream');
            obj.UIhandles.TimeScaleUpButton = uicontrol('Style', 'pushbutton', 'String', '>', 'Position', [970 10 50 50],...
                'Callback',@(h,e)obj.stepTimescale(1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Increase time/div');
            obj.UIhandles.TimeScaleDnButton = uicontrol('Style', 'pushbutton', 'String', '<', 'Position', [845 10 50 50],...
                'Callback',@(h,e)obj.stepTimescale(-1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Decrease time/div');
            uicontrol('Style', 'text', 'Position', [895 37 70 30], 'String', 'Time', 'FontSize', scaleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [895 10 70 30], 'String', '/ div', 'FontSize', scaleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            obj.UIhandles.VoltScaleUpButton = uicontrol('Style', 'pushbutton', 'String', '^', 'Position', [780 10 50 50],...
                'Callback',@(h,e)obj.stepVoltscale(1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Increase volts/div');
            obj.UIhandles.VoltScaleDnButton = uicontrol('Style', 'pushbutton', 'String', 'v', 'Position', [660 10 50 50],...
                'Callback',@(h,e)obj.stepVoltscale(-1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', titleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Decrease volts/div');
            uicontrol('Style', 'text', 'Position', [710 37 70 30], 'String', 'Volts', 'FontSize', scaleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [710 10 70 30], 'String', '/ div', 'FontSize', scaleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [650 310 70 30], 'String', 'View', 'FontSize', subTitleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [720 310 90 30], 'String', 'Range', 'FontSize', subTitleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [800 310 90 30], 'String', 'Events', 'FontSize', subTitleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [887 310 60 30], 'String', 'Thrsh', 'FontSize', subTitleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [955 310 60 30], 'String', 'Reset', 'FontSize', subTitleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [653 460 110 30], 'String', 'Sampling', 'FontSize', titleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [667 420 65 30], 'String', '#Chan', 'FontSize', subTitleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [740 420 140 30], 'String', 'Freq (Hz)', 'FontSize', subTitleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [653 350 55 30], 'String', 'File:', 'FontSize', titleFontSize,...
                'BackgroundColor', oscBGColor, 'FontWeight', 'bold');
            obj.UIhandles.SFEdit = uicontrol('Style', 'edit', 'Position', [760 390 100 30], 'String',... 
                                             num2str(obj.SamplingRate), 'FontSize', 12,...
                'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Callback',@(h,e)obj.UIsetSamplingRate());
            obj.UIhandles.DataFileEdit = uicontrol('Style', 'edit', 'Position', [713 350 301 30], 'String',... 
                obj.USBStreamFile, 'FontSize', 10, 'BackgroundColor', [0.8 0.8 0.8], 'FontName', 'Courier New',... 
                'FontWeight', 'bold', 'Callback',@(h,e)obj.setStreamFileFromGUI(),... 
                'TooltipString', 'Full path to .mat file to store acquired data from channels selected below (optional).');
            obj.UIhandles.nChanSelect = uicontrol('Style', 'popupmenu', 'Position', [670 390 65 30],... 
                'String', {'1','2','3','4','5','6','7','8'}, 'FontSize', 12, 'BackgroundColor', [0.8 0.8 0.8],... 
                'FontWeight', 'bold', 'Value', obj.nActiveChannels, 'Callback',@(h,e)obj.UIsetNactiveChannels());
            yPos = 285;
            enableStrings = {'off', 'on'};
            for i = 1:obj.nPhysicalChannels
                uicontrol('Style', 'text', 'Position', [655 yPos 35 20], 'String', ['Ch' num2str(i)], 'FontSize', 12,...
                    'BackgroundColor', oscBGColor, 'FontWeight', 'bold', 'ForegroundColor', lineColors{i});
                obj.UIhandles.chanEnable(i) = uicontrol('Style', 'checkbox', 'Position', [700 yPos 20 20], 'FontSize', 12,...
                    'BackgroundColor', oscBGColor, 'FontWeight', 'bold', 'Value', obj.Stream2USB(i),... 
                    'Callback',@(h,e)obj.UIenableChannel(i));
                obj.UIhandles.rangeSelect(i) = uicontrol('Style', 'popupmenu', 'Position', [730 yPos 97 20],... 
                    'FontSize', dropFontSize, 'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold',... 
                    'Value', obj.RangeIndex(i), 'Callback',@(h,e)obj.UIsetRange(i),...
                    'String',obj.Info.InputVoltageRanges, 'enable', enableStrings{(i<= obj.nActiveChannels)+1});
                obj.UIhandles.SMeventEnable(i) = uicontrol('Style', 'checkbox', 'Position', [845 yPos 20 20], 'FontSize', 12,...
                    'BackgroundColor', oscBGColor, 'FontWeight', 'bold', 'Value', obj.SMeventsEnabled(i),... 
                    'Callback',@(h,e)obj.UIenableSMEvents(i),... 
                    'TooltipString', ['Send threshold crossing events from channel ' num2str(i) ' to state machine']);
                obj.UIhandles.thresholdSet(i) = uicontrol('Style', 'edit', 'Position', [890 yPos 55 20], 'FontSize', 10,...
                    'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Callback',@(h,e)obj.UIsetThreshold(i),...
                    'String',num2str(obj.Thresholds(1,i)), 'enable', enableStrings{obj.SMeventsEnabled(i)+1});
                obj.UIhandles.resetSet(i) = uicontrol('Style', 'edit', 'Position', [960 yPos 55 20], 'FontSize', 10,...
                    'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Callback',@(h,e)obj.UIsetReset(i),...
                    'String',num2str(obj.ResetVoltages(1,i)), 'enable', enableStrings{obj.SMeventsEnabled(i)+1});
                yPos= yPos - 30;
            end
            set(obj.UIhandles.chanEnable(1), 'Value', 1);
            obj.Stream2USB(1) = 1;
            drawnow;
        end
        
        function scope_StartStop(obj)
            % scope_StartStop() toggles data acquisition by the scope()
            % GUI. It is called by a start button on the GUI, but it can also be 
            % called from a user protocol file to start analog data logging with
            % online monitoring.
            scopeReady = 1;
            if ~isfield(obj.UIhandles, 'OscopeFig')
                scopeReady = 0;
            elseif isempty(obj.UIhandles.OscopeFig)
                scopeReady = 0;
            end
            if scopeReady
                if obj.Streaming == 0
                    obj.Streaming = 1;
                    set(obj.UIhandles.SFEdit, 'String', num2str(obj.SamplingRate));
                    set(obj.UIhandles.DataFileEdit, 'String', obj.USBStreamFile);
                    set(obj.UIhandles.nChanSelect, 'Value', obj.nActiveChannels);
                    set(obj.UIhandles.StatText, 'String', 'Running', 'Color', 'green');
                    set(obj.UIhandles.RunButton, 'String', 'Stop');
                    if obj.USBstream2File
                        activeChannels = find(obj.Stream2USB(1:obj.nActiveChannels));
                        InfoStruct = struct;
                        InfoStruct.HardwareVersion = obj.Info.HardwareVersion;
                        InfoStruct.FirmwareVersion = obj.Info.FirmwareVersion;
                        InfoStruct.SamplingRate_Hz = obj.SamplingRate;
                        InfoStruct.ChannelInputRanges_V = obj.InputRange;
                        InfoStruct.SampleUnits = 'Volts';
                        InfoStruct.EventTimeUnits = 'Samples';
                        InfoStruct.ChannelsRecorded = activeChannels;
                        InfoStruct.FileDateTime = datestr(now);
                        obj.USBstreamFile.Info = InfoStruct;
                        set(obj.UIhandles.RecStatText, 'String', 'Recording');
                    end
                    obj.UIdata.SweepPos = 1;
                    obj.startUSBStream;
                    obj.Timer = timer('TimerFcn',@(h,e)obj.updatePlot(), 'ExecutionMode', 'fixedRate', 'Period', 0.05);
                    start(obj.Timer);
                else
                    stop(obj.Timer);
                    obj.stopUSBStream;
                    set(obj.UIhandles.DataFileEdit, 'String', obj.USBStreamFile);
                    set(obj.UIhandles.StatText, 'String', 'Stopped', 'Color', 'red');
                    set(obj.UIhandles.RunButton, 'String', 'Run');
                    set(obj.UIhandles.RecStatText, 'String', '');
                    obj.Streaming = 0;
                    delete(obj.Timer);
                    pause(.1);
                    ba = obj.Port.bytesAvailable;
                    if ba > 0
                        obj.Port.read(obj.Port.bytesAvailable, 'uint8');
                    end
                end
                drawnow;
            end
        end

        function result = testPSRAM(obj)
            % Test the module's 8MB PSRAM IC. As of firmware v6 the PSRAM IC is
            % not used. It is installed for future features, or custom user firmware.
            if obj.Info.HardwareVersion ~= 2
                error('Bpod Analog Input Module v1 does not have PSRAM.')
            end
            obj.Port.write([obj.opMenuByte '%'], 'uint8');
            disp('Testing PSRAM. This may take up to 20 seconds.');
            while obj.Port.bytesAvailable < 2
                pause(.1);
            end
            memSize = obj.Port.read(1, 'uint8');
            result = obj.Port.read(1, 'uint8');
            if result
                disp(['Test PASSED. ' num2str(memSize) ' MB detected.']);
            else
                disp('Test FAILED');
            end
        end
        
        function endAcq(obj)
            % Stop data acquisition with the scope() GUI. This method is
            % called when the GUI is closed, or can be called from the
            % user's protocol file.
            obj.stopUIStream;
            delete(obj.UIhandles.OscopeFig);
            obj.UIhandles.OscopeFig = [];
        end
        
        function delete(obj)
            % Class destructor
            try
                obj.Port.write([obj.opMenuByte 'X'], 'uint8');
                pause(.01);
            catch
            end
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
        
    end
    
    methods (Access = private)
        function confirmTransmission(obj,paramName)
            confirmed = obj.Port.read(1, 'uint8');
            if confirmed == 0
                error(['Error setting ' paramName ': the module denied your request.'])
            elseif confirmed ~= 1
                error(['Error setting ' paramName ': module did not acknowledge the new value.']);
            end
        end

        function stopUIStream(obj)
            if obj.Streaming
                obj.stopUSBStream;
                stop(obj.Timer);
                pause(.1);
                if obj.Port.bytesAvailable > 0
                    obj.Port.read(obj.Port.bytesAvailable, 'uint8');
                end
            end
        end

        function setStreamFileFromGUI(obj)
            fileName = get(obj.UIhandles.DataFileEdit, 'String');
            try
                obj.USBStreamFile = fileName;
            catch
                set(obj.UIhandles.DataFileEdit, 'String', obj.USBStreamFile);
                rethrow(lasterror);
            end
        end

        function updateThresholdLine(obj, chan)
            currentVoltDivValue = obj.UIdata.VoltDivValues(obj.UIdata.VoltDivPos);
            maxVolts = currentVoltDivValue*(obj.UIhandles.nYDivisions); HalfMax = maxVolts/2;
            threshY = ((obj.Thresholds(1,chan)+HalfMax)/maxVolts)*obj.UIhandles.nYDivisions;
            set(obj.UIhandles.ThresholdLine(chan), 'YData', [threshY,threshY]);
            resetY = ((obj.ResetVoltages(1,chan)+HalfMax)/maxVolts)*obj.UIhandles.nYDivisions;
            set(obj.UIhandles.ResetLine(chan), 'YData', [resetY,resetY]);
        end

        function bits = Volts2Bits(obj, voltVector, rangeIndexes)
            voltVector = double(voltVector);
            nElements = length(voltVector);
            bits = zeros(1,nElements);
            for i = 1:nElements
                thisMultiplier = obj.RangeVoltageSpan(rangeIndexes(i));
                thisOffset = obj.RangeOffsets(rangeIndexes(i));
                bits(i) = ((voltVector(i) + thisOffset)/thisMultiplier)*(obj.chBits-1);
            end
        end

        function valueOut = ScaleValue(obj, action, valueIn, RangeString)
            
            %validate input: nrows in ValueIn == n values in Range
            bitWidth = obj.chBits-1;
            if obj.Info.HardwareVersion == 1
                bitWidth = 2^13;
            end
            valueOut = nan(size(valueIn));
            for i=1:size(valueIn,1)
                thisRange = obj.RangeIndex(i);
                switch action
                    case 'toVolts'
                        valueOut(i,:) = double(valueIn(i,:)) * obj.RangeVoltageSpan(thisRange)/bitWidth -... 
                                        obj.RangeOffsets(thisRange);
                    case 'toBits'
                        valueOut(i,:) = uint32((valueIn(i,:) + obj.RangeOffsets(thisRange)) *... 
                                        bitWidth/obj.RangeVoltageSpan(thisRange));
                end
            end
        end

        function stepTimescale(obj, step)
            newPos = obj.UIdata.TimeDivPos + step;
            if (newPos > 0) && (newPos <= length(obj.UIdata.TimeDivValues))
                obj.UIdata.TimeDivPos = obj.UIdata.TimeDivPos + step;
                newTimeDivValue = obj.UIdata.TimeDivValues(obj.UIdata.TimeDivPos);
                nSamplesPerSweep = obj.SamplingRate*newTimeDivValue*obj.UIhandles.nXDivisions;
                interval = obj.UIhandles.nXDivisions/(nSamplesPerSweep-1);
                obj.UIdata.Xdata = 0:interval:obj.UIhandles.nXDivisions;
                obj.UIdata.Ydata = nan(obj.nPhysicalChannels,nSamplesPerSweep);
                obj.UIdata.SweepPos = 1;
                for i = 1:obj.nPhysicalChannels
                    set(obj.UIhandles.OscopeDataLine(i), 'XData', [obj.UIdata.Xdata,obj.UIdata.Xdata],... 
                        'YData', [obj.UIdata.Ydata(i,:),obj.UIdata.Ydata(i,:)]);
                end
                obj.UIdata.nDisplaySamples = nSamplesPerSweep;
                if newTimeDivValue >= 1
                    timeString = ['Time: ' num2str(newTimeDivValue) '.00s'];
                else
                    timeString = ['Time: ' num2str(newTimeDivValue*1000) '.0ms'];
                end
                set(obj.UIhandles.TimeText, 'String', timeString);
            end
        end

        function stepVoltscale(obj, step)
            newPos = obj.UIdata.VoltDivPos + step;
            if (newPos > 0) && (newPos <= length(obj.UIdata.VoltDivValues))
                obj.UIdata.VoltDivPos = obj.UIdata.VoltDivPos + step;
                obj.UIdata.SweepPos = 1;
                obj.UIdata.Ydata = nan(obj.nPhysicalChannels,obj.UIdata.nDisplaySamples);
                newVoltsDiv = obj.UIdata.VoltDivValues(newPos);
                if newVoltsDiv >= 1
                    voltString = ['V/div: ' num2str(newVoltsDiv) '.0'];
                else
                    voltString = ['mV/div: ' num2str(newVoltsDiv*1000) '.0'];
                end
                set(obj.UIhandles.VDivText, 'String', voltString);
                for i = 1:obj.nPhysicalChannels
                    if obj.SMeventsEnabled(i)
                        obj.updateThresholdLine(i);
                    end
                end
            end
        end

        function UIsetSamplingRate(obj)
            obj.stopUIStream;
            validSF = 1;
            sfString = get(obj.UIhandles.SFEdit, 'String');
            sf = str2double(sfString);
            if ~isnan(sf)
                sf = round(sf);
                if (sf >= obj.Info.SamplingRateRange(1)) && (sf <= obj.Info.SamplingRateRange(2))
                    validSF = 1;
                end
            end
            if validSF == 1
                try
                    obj.SamplingRate = sf;
                catch
                    set(obj.UIhandles.SFEdit, 'String', num2str(obj.SamplingRate));
                    rethrow(lasterror);
                end
                obj.stepTimescale(0); % Adjusts display time scale to same window setting at new SF
            else
                set(obj.UIhandles.SFEdit, 'String', num2str(obj.SamplingRate));
            end
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end

        function UIsetNactiveChannels(obj)
            nActiveChan = get(obj.UIhandles.nChanSelect, 'Value');
            obj.stopUIStream;
            if nActiveChan <= obj.nPhysicalChannels
                for i = 1:nActiveChan
                    set(obj.UIhandles.chanEnable(i), 'enable', 'on');
                    set(obj.UIhandles.rangeSelect(i), 'enable', 'on');
                end
                for i = nActiveChan+1:obj.nPhysicalChannels
                    obj.UIdata.Ydata(i,:) = NaN;
                    set(obj.UIhandles.OscopeDataLine(i), 'Ydata', [obj.UIdata.Ydata(i,:),obj.UIdata.Ydata(i,:)]);
                    set(obj.UIhandles.chanEnable(i), 'value', 0);
                    set(obj.UIhandles.chanEnable(i), 'enable', 'off');
                    set(obj.UIhandles.rangeSelect(i), 'enable', 'off');
                end
                obj.nActiveChannels = nActiveChan;
            end
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end

        function UIenableChannel(obj, chan)
            obj.stopUIStream;
            value = get(obj.UIhandles.chanEnable(chan), 'Value');
            obj.Stream2USB(chan) = value;
            obj.UIdata.Ydata(chan,:) = NaN;
            set(obj.UIhandles.OscopeDataLine(chan), 'Ydata', [obj.UIdata.Ydata(chan,:),obj.UIdata.Ydata(chan,:)]);
            if obj.Streaming
                obj.startUSBStream;
                pause(.1);
                if obj.Port.bytesAvailable > 0 % First buffer-full may have mixed data, discard
                    obj.Port.read(obj.Port.bytesAvailable, 'uint8');
                end
                obj.UIdata.SweepPos = 1;
                start(obj.Timer);
            end
        end

        function UIenableSMEvents(obj, chan)
            obj.stopUIStream;
            value = get(obj.UIhandles.SMeventEnable(chan), 'Value');
            obj.SMeventsEnabled(chan) = value;
            if value == 0
                set(obj.UIhandles.ThresholdLine(chan), 'Visible', 'Off');
                set(obj.UIhandles.ResetLine(chan), 'Visible', 'Off');
            else
                set(obj.UIhandles.ThresholdLine(chan), 'Visible', 'On');
                set(obj.UIhandles.ResetLine(chan), 'Visible', 'On');
                obj.updateThresholdLine(chan);
            end
            if sum(obj.SMeventsEnabled) > 0
                obj.startReportingEvents;
            else
                obj.stopReportingEvents;
            end
            enableStrings = {'off', 'on'};
            set(obj.UIhandles.thresholdSet(chan), 'enable', enableStrings{value+1});
            set(obj.UIhandles.resetSet(chan), 'enable', enableStrings{value+1});
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end

        function UIsetRange(obj, chan)
            obj.stopUIStream;
            value = get(obj.UIhandles.rangeSelect(chan), 'Value');
            obj.InputRange{chan} = obj.Info.InputVoltageRanges{value};
            set(obj.UIhandles.thresholdSet(chan), 'String', num2str(obj.Thresholds(1,chan)));
            set(obj.UIhandles.resetSet(chan), 'String', num2str(obj.ResetVoltages(1,chan)));
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end

        function UIsetThreshold(obj, chan)
            obj.stopUIStream;
            newThresholdstr = get(obj.UIhandles.thresholdSet(chan), 'String');
            newThreshold = str2double(newThresholdstr);
            thisChannelRange = obj.RangeIndex(chan);
            thisChannelMin = obj.InputRangeLimits(thisChannelRange, 1);
            thisChannelMax = obj.InputRangeLimits(thisChannelRange, 2);
            ValidThreshold = 0;
            if ~isnan(newThreshold)
                if (newThreshold >= thisChannelMin) && (newThreshold <= thisChannelMax) && isreal(newThreshold)
                    obj.Thresholds(1,chan) = newThreshold;
                    ValidThreshold = 1;
                    obj.updateThresholdLine(chan);
                end
            end
            if ~ValidThreshold
                set(obj.UIhandles.thresholdSet(chan), 'String', num2str(obj.Thresholds(1,chan)));
            end
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end

        function UIsetReset(obj, chan)
            obj.stopUIStream;
            newThresholdstr = get(obj.UIhandles.resetSet(chan), 'String');
            newThreshold = str2double(newThresholdstr);
            thisChannelRange = obj.RangeIndex(chan);
            thisChannelMin = obj.InputRangeLimits(thisChannelRange, 1);
            thisChannelMax = obj.InputRangeLimits(thisChannelRange, 2);
            validThreshold = 0;
            if ~isnan(newThreshold)
                if (newThreshold >= thisChannelMin) && (newThreshold <= thisChannelMax) && isreal(newThreshold)
                    obj.ResetVoltages(1,chan) = newThreshold;
                    validThreshold = 1;
                    obj.updateThresholdLine(chan);
                end
            end
            if ~validThreshold
                set(obj.UIhandles.resetSet(chan), 'String', num2str(obj.ResetVoltages(1,chan)));
            end
            if obj.Streaming
                obj.startUSBStream;
                start(obj.Timer);
            end
        end

        function updatePlot(obj)
            nBytesAvailable = obj.Port.bytesAvailable;
            channelsStreaming = obj.Stream2USB(1:obj.nActiveChannels);
            nChannelsStreaming = sum(channelsStreaming);
            updateChannels = find(channelsStreaming);
            nBytesPerFrame = (nChannelsStreaming*2)+2;
            if nChannelsStreaming > 0
                if nBytesAvailable > nBytesPerFrame % If at least 1 sample is available for each channel
                    nBytesToRead = floor(nBytesAvailable/nBytesPerFrame)*nBytesPerFrame;
                    newData = obj.Port.read(nBytesToRead, 'uint8');
                    currentVoltDivValue = obj.UIdata.VoltDivValues(obj.UIdata.VoltDivPos);
                    Prefix = newData(1);
                    if Prefix == 'R' || Prefix == '#'
                        Prefixes = newData(1:nBytesPerFrame:end);
                        newData(1:nBytesPerFrame:end) = [];
                        syncData = newData(1:nBytesPerFrame-1:end);
                        newData(1:nBytesPerFrame-1:end) = []; % Spacer
                        NewSamples = typecast(newData(1:end), 'uint16');
                        nNewSamples = length(NewSamples)/nChannelsStreaming;
                        sweepPos = obj.UIdata.SweepPos;
                        syncPrefixes = (Prefixes == '#');
                        nSyncEvents = sum(syncPrefixes);
                        syncPrefixPositions = find(syncPrefixes);
                        sampleDataForFile = zeros(nChannelsStreaming, nNewSamples);
                        for ch = 1:nChannelsStreaming
                            thisChIndex = updateChannels(ch);
                            nsThisCh = NewSamples(ch:nChannelsStreaming:end);
                            m = obj.RangeVoltageSpan(obj.RangeIndex(thisChIndex));
                            o = obj.RangeOffsets(obj.RangeIndex(thisChIndex));
                            nsThisChVolts = ((double(nsThisCh)/(obj.chBits-1))*m)-o;
                            if obj.USBstream2File
                                sampleDataForFile(ch,:) = nsThisChVolts;
                            end
                            maxVolts = currentVoltDivValue*(obj.UIhandles.nYDivisions);
                            halfMax = maxVolts/2;
                            nsThisChVolts(nsThisChVolts<maxVolts*-1 & nsThisChVolts>maxVolts) = NaN;
                            nsThisChSamples = ((nsThisChVolts+halfMax)/maxVolts)*obj.UIhandles.nYDivisions;
                            if sweepPos == 1
                                obj.UIdata.Ydata(thisChIndex,:) = NaN;
                                obj.UIdata.Ydata(thisChIndex,1:nNewSamples) = nsThisChSamples;
                                obj.UIdata.SweepPos = sweepPos + nNewSamples;
                            elseif sweepPos + nNewSamples > obj.UIdata.nDisplaySamples
                                obj.UIdata.Ydata(thisChIndex,sweepPos:obj.UIdata.nDisplaySamples-1) =... 
                                    nsThisChSamples(1:(obj.UIdata.nDisplaySamples-sweepPos));
                                obj.UIdata.SweepPos = 1;
                            else
                                obj.UIdata.Ydata(thisChIndex,sweepPos:sweepPos+nNewSamples-1) = nsThisChSamples;
                                obj.UIdata.SweepPos = sweepPos + nNewSamples;
                            end
                            set(obj.UIhandles.OscopeDataLine(thisChIndex), 'Ydata',... 
                                [obj.UIdata.Ydata(thisChIndex,:),obj.UIdata.Ydata(thisChIndex,:)]);
                        end
                        if obj.USBstream2File
                            obj.USBstreamFile.Samples(1:nChannelsStreaming,...
                                obj.USBFile_SamplePos:obj.USBFile_SamplePos+nNewSamples-1) = sampleDataForFile;
                        end
                        if nSyncEvents > 0
                            obj.USBstreamFile.SyncEvents(1,obj.USBFile_EventPos:obj.USBFile_EventPos+nSyncEvents-1) =... 
                                double(syncData(syncPrefixes));
                            obj.USBstreamFile.SyncEventTimes(1,obj.USBFile_EventPos:obj.USBFile_EventPos+nSyncEvents-1) =... 
                                double(syncPrefixPositions + obj.USBFile_SamplePos - 1);
                            obj.USBFile_EventPos = obj.USBFile_EventPos + nSyncEvents;
                        end
                        obj.USBFile_SamplePos = obj.USBFile_SamplePos + nNewSamples;
                    else
                        stop(obj.Timer);
                        delete(obj.Timer);
                        error('Error: invalid frame returned.')
                    end
                end
            end
        end
    end
end