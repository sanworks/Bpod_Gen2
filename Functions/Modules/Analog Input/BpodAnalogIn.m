%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2023 Sanworks LLC, Rochester, New York, USA

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

classdef BpodAnalogIn < handle
    
    properties
        About = struct; % Contains a text string describing each field
        Info = struct; % Contains useful info about the specific hardware detected
        Port % ArCOM Serial port
        Timer % MATLAB timer object
        Status % Struct containing status of ongoing ops (logging, streaming, etc)
        nActiveChannels % Number of channels to sample (consecutive, beginning with channel 1)
        SamplingRate % 1Hz-10kHz on v1, 1Hz-50kHz on v2, affects all channels
        InputRange % A cell array of strings indicating voltage range for 12-bit conversion. Valid ranges are in Info.InputVoltageRanges (below)
        Thresholds % Threshold (V) for each channel. Analog signal crossing the threshold generates an event.
        ResetVoltages % Voltage must cross ResetValue (V) before another threshold event can occur (except in Threshold Mode 1, see above)
        SMeventsEnabled % Logical vector indicating channels that generate events
        Stream2USB % Logical vector indicating channels to stream to USB when streaming is enabled
        Stream2Module % Logical vector indicating channels to stream via Ethernet cable directly to an analog output or DDS module (raw data)
        StreamPrefix % Prefix byte sent before each sample when streaming to output module
        nSamplesToLog = Inf; % Number of samples to log to microSD on trigger, 0 = infinite
        USBStreamFile = []; % Full path to file for data acquired with scope() GUI. If empty, scope() data is not saved.
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
            ShowWarnings = 1;
            obj.Info.FirmwareVersion = NaN;
            obj.Info.HardwareVersion = NaN;
            obj.Info.InputVoltageRanges = NaN;
            UsePsychToolbox = [];
            if nargin > 1
                Op = varargin{1};
                switch Op
                    case 'nowarnings'
                        ShowWarnings = 0;
                    case 'psychtoolbox'
                        UsePsychToolbox = 'psychtoolbox';
                end
            end
            obj.Port = ArCOMObject_Bpod(portString, 12000000, UsePsychToolbox, [], 1000000, 1000000); %115200
            obj.Port.write([obj.opMenuByte 'O'], 'uint8');
            HandShakeOkByte = obj.Port.read(1, 'uint8');
            if HandShakeOkByte == 161 % Correct handshake response
                obj.Info.FirmwareVersion = obj.Port.read(1, 'uint32');
                try
                    addpath(fullfile(fileparts(which('Bpod')), 'Functions', 'Internal Functions'));
                    CurrentFirmware = CurrentFirmwareList;
                    LatestFirmware = CurrentFirmware.AnalogIn;
                catch
                    % Stand-alone configuration (Bpod not installed); assume latest firmware
                    LatestFirmware = obj.Info.FirmwareVersion;
                end
                if obj.Info.FirmwareVersion < LatestFirmware
                    if ShowWarnings == 1
                        disp('*********************************************************************');
                        disp(['Warning: Old firmware detected: v' num2str(obj.Info.FirmwareVersion) ...
                            '. The current version is: v' num2str(LatestFirmware) char(13)...
                            'Please update using the firmware update tool: LoadBpodFirmware().'])
                        disp('*********************************************************************');
                    end
                elseif obj.Info.FirmwareVersion > LatestFirmware
                    error(['Analog Input Module with future firmware found. Please update your Bpod software from the Bpod_Gen2 repository.']);
                end
                obj.Info.HardwareVersion = 1;
                if obj.Info.FirmwareVersion > 4
                    obj.Port.write([obj.opMenuByte 'H'], 'uint8');
                    obj.Info.HardwareVersion = obj.Port.read(1, 'uint8');
                    if isempty(UsePsychToolbox)
                        obj.Port.write([obj.opMenuByte 't' 1], 'uint8'); % Throttle USB for Teensy 4.1 + MATLAB built-in serial interface
                    else
                        obj.Port.write([obj.opMenuByte 't' 0], 'uint8');
                    end
                    % If HW version 2, restart serial port with Teensy 4's correct baud rate --> buffer sizes
                    if obj.Info.HardwareVersion == 2
                        obj.Port = [];
                        pause(.2);
                        obj.Port = ArCOMObject_Bpod(portString, 480000000, UsePsychToolbox);
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
                        obj.Info.InputVoltageRanges = {'-2.5V:2.5V', '-5V:5V', '-6.25V:6.25V', '-10V:10V', '-12.5V:12.5V',...
                                                        '0V:5V', '0V:10V', '0V:12.5V'};
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
            
            obj.About.Port = 'ArCOM USB serial port object, to simplify data transactions with Arduino. See https://github.com/sanworks/ArCOM';
            obj.About.GUIhandles = 'A struct containing handles of the UI';
            obj.About.Status = 'A struct containing process status: logging, streaming to output module, returning threshold events to state machine';
            obj.About.SamplingRate = 'Sampling rate for all channels (in Hz)';
            obj.About.InputRange = 'Voltage range mapped to 12 bits of each channel. Valid ranges are in .Info.InputVoltageRanges';
            obj.About.nActiveChannels = 'Number of channels to read, beginning with channel 1. Fewer channels -> faster sampling.';
            obj.About.Thresholds = 'Threshold, in volts, generates an event when crossed. The event will be sent to the state machine if SendBpodEvents was called earlier.';
            obj.About.ResetVoltages = 'Threshold reset voltages for each channel. Voltage must go below this value to enable the next event.';
            obj.About.SMeventsEnabled = 'Logical vector indicating channels that generate threshold crossing events';
            obj.About.Stream2USB = 'Logical vector indicating which channels stream raw data to USB.';
            obj.About.Stream2Module = 'Logical vector indicating which channels stream raw data to output module.';
            obj.About.nSamplesToLog = 'Number of samples to log following a call to StartSDlogging() or serial log command from the state machine. 0 = Infinite.';
            obj.About.METHODS = 'type methods(myObject) at the command line to see a list of valid methods.';            

        end
        function set.nSamplesToLog(obj, nSamples)
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
            if obj.Initialized
                if obj.USBstream2File
                    error('Error: The analog input module sampling rate cannot be changed while streaming to a file.');
                end
                if sf < obj.Info.SamplingRateRange(1) || sf > obj.Info.SamplingRateRange(2)
                    error(['Error setting sampling rate: valid rates are in range: [' num2str(obj.Info.SamplingRateRange) '] Hz'])
                end
                obj.Port.write([obj.opMenuByte 'F'], 'uint8', sf,'uint32');
                obj.confirmTransmission('sampling rate');
            end
            obj.SamplingRate = sf;
        end
        
        function set.StreamPrefix(obj, prefix)
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
            obj.USBstream2File = false;
            if isempty(fileName)
                obj.USBStreamFile = [];
                obj.USBstreamFile = [];
            else
                FP = fileparts(fileName);
                if isempty(FP)
                    error(['Error setting AnalogInput data file: ' fileName ' is not a valid filename. The filename must be the full path of the target data file.'])
                end
                if exist(FP) ~= 7
                    error(['Error setting AnalogInput data file: ' FP ' is not a valid folder.'])
                end
                if exist(fileName) == 2
                    error(['Error setting AnalogInput data file: ' fileName ' already exists. Please manually delete the file or change the target filename before acquiring.'])
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
        
        function set.nActiveChannels(obj, nChannels)
            if obj.Initialized
                if obj.USBstream2File
                    error('Error: The analog input module active channel set cannot be changed while streaming to a file.');
                end
                if nChannels < 1 || nChannels > obj.nPhysicalChannels
                    error(['Error setting active channel count: nChannels must be in the range 1:' num2str(obj.nPhysicalChannels)]);
                end
                obj.Port.write([obj.opMenuByte 'A' nChannels], 'uint8');
                obj.confirmTransmission('active channels');
            end
            obj.nActiveChannels = nChannels;
        end
        
        function set.InputRange(obj, value)
            if obj.Initialized
                if obj.USBstream2File
                    error('Error: The analog input module voltage range cannot be changed while streaming to a file.');
                end
                InputRangeIndex = ones(1,obj.nPhysicalChannels);
                InputRangeIndexCode = ones(1, obj.nPhysicalChannels);
                for i = 1:obj.nPhysicalChannels
                    RangeString = value{i};
                    RangeIndex = find(strcmp(RangeString, obj.Info.InputVoltageRanges),1);
                    if isempty(RangeIndex)
                        RangeListString = [];
                        for i = 1:length(obj.Info.InputVoltageRanges)
                            RangeListString = [RangeListString char(10) obj.Info.InputVoltageRanges{i}];
                        end
                        error(['Invalid range specified: ' RangeString '. Valid ranges are: ' RangeListString]);
                    end
                    InputRangeIndex(i) = RangeIndex;
                    InputRangeIndexCode(i) = obj.RangeCodes(RangeIndex);
                end
                obj.Port.write([obj.opMenuByte 'R' InputRangeIndexCode], 'uint8');
                obj.confirmTransmission('voltage range');
                oldRangeIndex = obj.RangeIndex;
                obj.RangeIndex = InputRangeIndex;
                % Set thresholds and reset values (expressed in voltages) to values in new range.
                % Thresholds that are out of range are set to maximum range.
                [ydimThresh,xdimThresh] = size(obj.Thresholds);
                [ydimReset,xdimReset] = size(obj.ResetVoltages);
                NewThresholds = obj.Thresholds;
                NewResets = obj.ResetVoltages;
                for i = 1:obj.nPhysicalChannels
                    ThisRangeMin = obj.InputRangeLimits(obj.RangeIndex(i),1);
                    ThisRangeMax = obj.InputRangeLimits(obj.RangeIndex(i),2);
                    for j = 1:ydimThresh
                        if NewThresholds(j,i) < ThisRangeMin
                            NewThresholds(j,i) = ThisRangeMin;
                        elseif NewThresholds(j,i) > ThisRangeMax
                            NewThresholds(j,i) = ThisRangeMax;
                        end
                        if obj.Thresholds(j,i) == obj.InputRangeLimits(oldRangeIndex(i), 2)
                            NewThresholds(j,i) = ThisRangeMax;
                        end
                    end
                    for j = 1:ydimReset
                        if NewResets(j,i) < ThisRangeMin
                            NewResets(j,i) = ThisRangeMin;
                        elseif NewResets(j,i) > ThisRangeMax
                            NewResets(j,i) = ThisRangeMax;
                        end
                        if obj.ResetVoltages(j,i) == obj.InputRangeLimits(oldRangeIndex(i), 1)
                            NewResets(j,i) = ThisRangeMin;
                        end
                    end
                end
                Ranges = obj.RangeIndex;
                if obj.Info.FirmwareVersion > 5
                    Ranges = [Ranges obj.RangeIndex];
                end
                obj.InputRange = value;
                % Reset and threshold must be set simultanesously, since they
                % were changed simultaneously. Instead of calling
                % set.Thresholds, and set.ResetVoltages, the next 4 lines do both at once.
                NewThresholdVector = reshape(NewThresholds',1,[]);
                if obj.Info.FirmwareVersion > 5 && ydimThresh == 1
                    NewThresholdVector = [NewThresholdVector obj.InputRangeLimits(obj.RangeIndex,2)'];
                end
                ThresholdBits = obj.Volts2Bits(NewThresholdVector, Ranges);
                NewResetsVector = reshape(NewResets',1,[]);
                if obj.Info.FirmwareVersion > 5 && ydimReset == 1
                    NewResetsVector = [NewResetsVector obj.InputRangeLimits(obj.RangeIndex,1)'];
                end
                ResetValueBits = obj.Volts2Bits(NewResetsVector, Ranges);
                obj.Port.write([obj.opMenuByte 'T'], 'uint8', [ThresholdBits ResetValueBits], 'uint16');
                obj.confirmTransmission('thresholds');
                obj.Initialized = 0; % Disable updating to change the object
                obj.Thresholds = NewThresholds;
                obj.ResetVoltages = NewResets;
                obj.Initialized = 1;
            else
                obj.InputRange = value;
            end
            
        end
        
        function set.Thresholds(obj, thersholdValues)
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
                    if newThresholds(i) < obj.InputRangeLimits(obj.RangeIndex(i),1) || newThresholds(i) > obj.InputRangeLimits(obj.RangeIndex(i),2)
                        error(['Error setting threshold: a threshold for channel ' num2str(i) ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                    end
                    if obj.Info.FirmwareVersion > 5
                        % Check threshold 2 for each channel
                        if newThresholds(i+obj.nPhysicalChannels) < obj.InputRangeLimits(obj.RangeIndex(i),1) || newThresholds(i+obj.nPhysicalChannels) > obj.InputRangeLimits(obj.RangeIndex(i),2)
                            error(['Error setting threshold: a threshold for channel ' num2str(i) ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                        end
                    end
                end
                
                %Convert thresholds to bits according to voltage range.
                Ranges = obj.RangeIndex;
                if obj.Info.FirmwareVersion > 5
                    Ranges = [Ranges obj.RangeIndex];
                end
                ResetValueBits = obj.Volts2Bits(newResetVoltages, Ranges);
                ThresholdBits = obj.Volts2Bits(newThresholds, Ranges);
                obj.Port.write([obj.opMenuByte 'T'], 'uint8', [ThresholdBits ResetValueBits], 'uint16');
                obj.confirmTransmission('thresholds');
            end
            obj.Thresholds = thersholdValues;
        end
        
        function set.ResetVoltages(obj, resetValues)
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
                    if newResetVoltages(i) < obj.InputRangeLimits(obj.RangeIndex(i),1) || newResetVoltages(i) > obj.InputRangeLimits(obj.RangeIndex(i),2)
                        error(['Error setting reset voltage: a reset voltage for channel ' num2str(i) ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                    end
                    if obj.Info.FirmwareVersion > 5
                        % Check threshold 2 for each channel
                        if newResetVoltages(i+obj.nPhysicalChannels) < obj.InputRangeLimits(obj.RangeIndex(i),1) || newResetVoltages(i+obj.nPhysicalChannels) > obj.InputRangeLimits(obj.RangeIndex(i),2)
                            error(['Error setting reset voltage: a reset voltage for channel ' num2str(i) ' is not within the channel''s voltage range: ' obj.InputRange{i}])
                        end
                    end
                end
                Ranges = obj.RangeIndex;
                if obj.Info.FirmwareVersion > 5
                    Ranges = [Ranges obj.RangeIndex];
                end
                %Convert thresholds to bits according to voltage range.
                ResetValueBits = obj.Volts2Bits(newResetVoltages, Ranges);
                ThresholdBits = obj.Volts2Bits(newThresholds, Ranges);
                obj.Port.write([obj.opMenuByte 'T'], 'uint8', [ThresholdBits ResetValueBits], 'uint16');
                obj.confirmTransmission('reset values');
            end
            obj.ResetVoltages = resetValues;
        end
        
        function set.SMeventsEnabled(obj, value)
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
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 1 1], 'uint8');
            end
            obj.confirmTransmission('Module stream');
            obj.Status.ModuleStreamEnabled = 1;
        end
        
        function stopModuleStream(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 1 0], 'uint8');
                obj.confirmTransmission('Module stream');
            end
            obj.Status.ModuleStreamEnabled = 0;
        end
        
        function startUSBStream(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 0 1], 'uint8');
                %obj.confirmTransmission('USB stream');
            end
            obj.Status.USBStreamEnabled = 1;
        end
        
        function stopUSBStream(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'S' 0 0], 'uint8');
                obj.USBStreamFile = []; % Stop writing to the current file
                % Do not confirm; data bytes in buffer may be expected by
                % another application
            end
            obj.Status.USBStreamEnabled = 0;
        end
        
        function startReportingEvents(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'E' 1 1], 'uint8');
                obj.confirmTransmission('event reporting');
            end
            obj.Status.EventReporting = 1;
        end
        
        function stopReportingEvents(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'E' 1 0], 'uint8');
                obj.confirmTransmission('event reporting');
            end
            obj.Status.EventReporting = 0;
        end
        
        function startLogging(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'L' 1], 'uint8');
                obj.confirmTransmission('start logging');
                obj.Status.Logging = 1;
            end
        end
        
        function stopLogging(obj)
            if obj.Initialized
                obj.Port.write([obj.opMenuByte 'L' 0], 'uint8');
                obj.confirmTransmission('stop logging');
                obj.Status.Logging = 0;
            end
        end
        
        function set.Stream2USB(obj, value)
            if obj.Initialized
                if ~(length(value) == obj.nPhysicalChannels && sum((value == 0) | (value == 1)) == obj.nPhysicalChannels)
                    error('Error setting Stream2USB channels: value for each channel must be 0 or 1')
                end
                Stream2Module = obj.Stream2Module;
                if isempty(Stream2Module) % This only occurs in the constructor
                    Stream2Module = zeros(1, obj.nPhysicalChannels);
                end
                obj.Port.write([obj.opMenuByte 'C' value Stream2Module], 'uint8');
                obj.confirmTransmission('stream to USB');
            end
            obj.Stream2USB = value;
        end
        
        function set.Stream2Module(obj, value)
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
        function FV = getFirmwareVersion(obj)
            FV = obj.Info.FirmwareVersion;
        end

        function voltage = readChannel(obj, chan)
            USBStreamConfig = obj.Stream2USB;
            NewStreamConfig = zeros(1,length(USBStreamConfig));
            NewStreamConfig(chan) = 1;
            obj.Stream2USB = NewStreamConfig;
            obj.startUSBStream;
            while obj.Port.bytesAvailable < 4
                pause(.001);
            end
            obj.stopUSBStream;
            Msg = obj.Port.read(2, 'uint16');
            pause(.1); % Pause to ensure that streaming has stopped
            obj.Port.flush;
            thisMultiplier = obj.RangeVoltageSpan(obj.RangeIndex(chan));
            thisOffset = obj.RangeOffsets(obj.RangeIndex(chan));
            voltage = ((double(Msg(2))/obj.chBits)*thisMultiplier)-thisOffset;
            obj.Stream2USB = USBStreamConfig;
        end

        function data = getData(obj)
            obj.Port.flush;
            % Send 'Retrieve' command to the AM
            obj.Port.write([obj.opMenuByte 'D'], 'uint8');
            nSamples = double(obj.Port.read(1, 'uint32'));
            nValues = double(obj.nActiveChannels*nSamples);
            RawData = zeros(1,nValues, 'uint16');
            MaxValuesToRead = 100000;
            nReads = floor(nValues/MaxValuesToRead);
            partialReadLength = nValues-(nReads*MaxValuesToRead);
            Pos = 1;
            for i = 1:nReads
                RawData(Pos:Pos+MaxValuesToRead-1) = obj.Port.read(MaxValuesToRead, 'uint16');
                Pos = Pos + MaxValuesToRead;
            end
            if partialReadLength > 0
                RawData(Pos:Pos+partialReadLength-1) = obj.Port.read(partialReadLength, 'uint16');
            end

            data = struct;
            data.y = zeros(obj.nActiveChannels, nSamples);
            ReshapedRawData = reshape(RawData, obj.nActiveChannels, nSamples);
            for i = 1:obj.nActiveChannels
                thisMultiplier = obj.RangeVoltageSpan(obj.RangeIndex(i));
                thisOffset = obj.RangeOffsets(obj.RangeIndex(i));
                data.y(i,:) = ((double(ReshapedRawData(i,:))/obj.chBits)*thisMultiplier)-thisOffset;
            end
            Period = 1/obj.SamplingRate;
            data.x = 0:Period:(Period*double(nSamples)-Period);
        end
        
        function setZero(obj)
            obj.Port.write([213 'Z'], 'uint8');
        end
        
        function Scope(obj)
            obj.scope;
        end
        
        function scope(obj)
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
            obj.UIdata.nDisplaySamples = obj.SamplingRate*obj.UIdata.TimeDivValues(obj.UIdata.TimeDivPos)*obj.UIhandles.nXDivisions;
            obj.UIdata.SweepPos = 1;
            if isunix && ~ismac
                TitleFontSize = 16;
                ScaleFontSize = 14;
                SubTitleFontSize = 12;
                lineEdge = 0.25;
                figHeight = 470;
                dropFontSize = 8;
            else
                TitleFontSize = 18;
                ScaleFontSize = 18;
                SubTitleFontSize = 16;
                lineEdge = 0;
                figHeight = 500;
                dropFontSize = 10;
            end
            OscBGColor = [0.55 0.55 0.55];
            LineColors = {[1 1 0], [0 1 1], [1 0.5 0], [0 1 0], [1 .3 .3], [.6 .2 1], [.3 .3 1], [1 0 1]};
            ResetLineColors = cell(1,obj.nPhysicalChannels);
            for i = 1:obj.nPhysicalChannels
                ResetLineColors{i} = LineColors{i}*0.5;
            end
            obj.UIhandles.OscopeFig = figure('Name','Scope',...
                'NumberTitle','off',...
                'MenuBar','none',...
                'Color',OscBGColor,...
                'Position',[100,100,1024,figHeight],...
                'CloseRequestFcn',@(h,e)obj.endAcq());
            obj.UIhandles.Plot = axes('units','pixels', 'position',[10 10 640 480], ...
                'box', 'off', 'tickdir', 'out', 'Color', [0.1 0.1 0.1]);
            set(gca, 'xlim', [0 obj.UIhandles.nXDivisions], 'ylim', [-0.4 obj.UIhandles.nYDivisions], 'ytick', [], 'xtick', []);
            Interval = obj.UIhandles.nXDivisions/obj.UIdata.nDisplaySamples;
            obj.UIdata.Xdata = 0:Interval:obj.UIhandles.nXDivisions-Interval;
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
                obj.UIhandles.OscopeDataLine(i) = line([obj.UIdata.Xdata,obj.UIdata.Xdata],[obj.UIdata.Ydata(i,:),obj.UIdata.Ydata(i,:)], 'Color', LineColors{i});
            end
            currentVoltDivValue = obj.UIdata.VoltDivValues(obj.UIdata.VoltDivPos);
            MaxVolts = currentVoltDivValue*(obj.UIhandles.nYDivisions); HalfMax = MaxVolts/2;
            VisibilityVec = {'Off', 'On'};
            for i = 1:obj.nPhysicalChannels
                ThreshY = ((obj.Thresholds(1,i)+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
                obj.UIhandles.ThresholdLine(i) = line([0 obj.UIhandles.nXDivisions],[ThreshY,ThreshY],...
                    'Color', LineColors{i}, 'LineStyle', ':', 'Visible', VisibilityVec{obj.SMeventsEnabled(i)+1});
                ResetY = ((obj.ResetVoltages(1,i)+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
                obj.UIhandles.ResetLine(i) = line([0 obj.UIhandles.nXDivisions],[ResetY,ResetY],...
                    'Color', ResetLineColors{i}, 'LineStyle', ':', 'Visible', VisibilityVec{obj.SMeventsEnabled(i)+1});
            end
            
            
            obj.UIhandles.MaskLine = line([lineEdge,obj.UIhandles.nXDivisions-lineEdge],[-0.2,-0.2], 'Color', [.2 .2 .2], 'LineWidth', 20);
            obj.UIhandles.VDivText = text(0.2,-0.2, 'V/div: 5.0', 'Color', 'yellow', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.TimeText = text(9.5,-0.2, 'Time 200.0ms', 'Color', 'yellow', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.StatText = text(0.2,7.7, 'Stopped', 'Color', 'red', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.RecStatText = text(10.1,7.7, '', 'Color', 'red', 'FontName', 'Courier New', 'FontSize', 12);
            obj.UIhandles.RunButton = uicontrol('Style', 'pushbutton', 'String', 'RUN', 'Position', [895 390 120 95],...
                'Callback',@(h,e)obj.scope_StartStop(), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Start/Stop Data Stream');
            obj.UIhandles.TimeScaleUpButton = uicontrol('Style', 'pushbutton', 'String', '>', 'Position', [970 10 50 50],...
                'Callback',@(h,e)obj.stepTimescale(1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Increase time/div');
            obj.UIhandles.TimeScaleDnButton = uicontrol('Style', 'pushbutton', 'String', '<', 'Position', [845 10 50 50],...
                'Callback',@(h,e)obj.stepTimescale(-1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Decrease time/div');
            uicontrol('Style', 'text', 'Position', [895 37 70 30], 'String', 'Time', 'FontSize', ScaleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [895 10 70 30], 'String', '/ div', 'FontSize', ScaleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            obj.UIhandles.VoltScaleUpButton = uicontrol('Style', 'pushbutton', 'String', '^', 'Position', [780 10 50 50],...
                'Callback',@(h,e)obj.stepVoltscale(1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Increase volts/div');
            obj.UIhandles.VoltScaleDnButton = uicontrol('Style', 'pushbutton', 'String', 'v', 'Position', [660 10 50 50],...
                'Callback',@(h,e)obj.stepVoltscale(-1), 'BackgroundColor', [0.7 0.7 0.7], 'FontSize', TitleFontSize,...
                'FontWeight', 'bold', 'TooltipString', 'Decrease volts/div');
            uicontrol('Style', 'text', 'Position', [710 37 70 30], 'String', 'Volts', 'FontSize', ScaleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [710 10 70 30], 'String', '/ div', 'FontSize', ScaleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [650 310 70 30], 'String', 'View', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [720 310 90 30], 'String', 'Range', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [800 310 90 30], 'String', 'Events', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [887 310 60 30], 'String', 'Thrsh', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [955 310 60 30], 'String', 'Reset', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [653 460 110 30], 'String', 'Sampling', 'FontSize', TitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [667 420 65 30], 'String', '#Chan', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [740 420 140 30], 'String', 'Freq (Hz)', 'FontSize', SubTitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            uicontrol('Style', 'text', 'Position', [653 350 55 30], 'String', 'File:', 'FontSize', TitleFontSize,...
                'BackgroundColor', OscBGColor, 'FontWeight', 'bold');
            obj.UIhandles.SFEdit = uicontrol('Style', 'edit', 'Position', [760 390 100 30], 'String', num2str(obj.SamplingRate), 'FontSize', 12,...
                'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Callback',@(h,e)obj.UIsetSamplingRate());
            obj.UIhandles.DataFileEdit = uicontrol('Style', 'edit', 'Position', [713 350 301 30], 'String', obj.USBStreamFile, 'FontSize', 10,...
                'BackgroundColor', [0.8 0.8 0.8], 'FontName', 'Courier New', 'FontWeight', 'bold', 'Callback',@(h,e)obj.setStreamFileFromGUI(), 'TooltipString', 'Full path to .mat file to store acquired data from channels selected below (optional).');
            obj.UIhandles.nChanSelect = uicontrol('Style', 'popupmenu', 'Position', [670 390 65 30], 'String', {'1','2','3','4','5','6','7','8'}, 'FontSize', 12,...
                'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Value', obj.nActiveChannels, 'Callback',@(h,e)obj.UIsetNactiveChannels());
            YPos = 285;
            EnableStrings = {'off', 'on'};
            for i = 1:obj.nPhysicalChannels
                uicontrol('Style', 'text', 'Position', [655 YPos 35 20], 'String', ['Ch' num2str(i)], 'FontSize', 12,...
                    'BackgroundColor', OscBGColor, 'FontWeight', 'bold', 'ForegroundColor', LineColors{i});
                obj.UIhandles.chanEnable(i) = uicontrol('Style', 'checkbox', 'Position', [700 YPos 20 20], 'FontSize', 12,...
                    'BackgroundColor', OscBGColor, 'FontWeight', 'bold', 'Value', obj.Stream2USB(i), 'Callback',@(h,e)obj.UIenableChannel(i));
                obj.UIhandles.rangeSelect(i) = uicontrol('Style', 'popupmenu', 'Position', [730 YPos 97 20], 'FontSize', dropFontSize,...
                    'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Value', obj.RangeIndex(i), 'Callback',@(h,e)obj.UIsetRange(i),...
                    'String',obj.Info.InputVoltageRanges, 'enable', EnableStrings{(i<= obj.nActiveChannels)+1});
                obj.UIhandles.SMeventEnable(i) = uicontrol('Style', 'checkbox', 'Position', [845 YPos 20 20], 'FontSize', 12,...
                    'BackgroundColor', OscBGColor, 'FontWeight', 'bold', 'Value', obj.SMeventsEnabled(i), 'Callback',@(h,e)obj.UIenableSMEvents(i),...
                    'TooltipString', ['Send threshold crossing events from channel ' num2str(i) ' to state machine']);
                obj.UIhandles.thresholdSet(i) = uicontrol('Style', 'edit', 'Position', [890 YPos 55 20], 'FontSize', 10,...
                    'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Callback',@(h,e)obj.UIsetThreshold(i),...
                    'String',num2str(obj.Thresholds(1,i)), 'enable', EnableStrings{obj.SMeventsEnabled(i)+1});
                obj.UIhandles.resetSet(i) = uicontrol('Style', 'edit', 'Position', [960 YPos 55 20], 'FontSize', 10,...
                    'BackgroundColor', [0.8 0.8 0.8], 'FontWeight', 'bold', 'Callback',@(h,e)obj.UIsetReset(i),...
                    'String',num2str(obj.ResetVoltages(1,i)), 'enable', EnableStrings{obj.SMeventsEnabled(i)+1});
                YPos= YPos - 30;
            end
            set(obj.UIhandles.chanEnable(1), 'Value', 1);
            obj.Stream2USB(1) = 1;
            drawnow;
        end
        
        function scope_StartStop(obj)
            ScopeReady = 1;
            if ~isfield(obj.UIhandles, 'OscopeFig')
                ScopeReady = 0;
            elseif isempty(obj.UIhandles.OscopeFig)
                ScopeReady = 0;
            end
            if ScopeReady
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
                    BA = obj.Port.bytesAvailable;
                    if BA > 0
                        obj.Port.read(obj.Port.bytesAvailable, 'uint8');
                    end
                end
                drawnow;
            end
        end

        function result = testPSRAM(obj)
            if obj.Info.HardwareVersion ~= 2
                error('Bpod Analog Input Module v1 does not have PSRAM.')
            end
            obj.Port.write([obj.opMenuByte '%'], 'uint8');
            disp(['Testing PSRAM. This may take up to 20 seconds.']);
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
            obj.stopUIStream;
            delete(obj.UIhandles.OscopeFig);
            obj.UIhandles.OscopeFig = [];
        end
        
        function delete(obj)
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
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed == 0
                error(['Error setting ' paramName ': the module denied your request.'])
            elseif Confirmed ~= 1
                error(['Error setting ' paramName ': module did not acknowledge new value.']);
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
            MaxVolts = currentVoltDivValue*(obj.UIhandles.nYDivisions); HalfMax = MaxVolts/2;
            ThreshY = ((obj.Thresholds(1,chan)+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
            set(obj.UIhandles.ThresholdLine(chan), 'YData', [ThreshY,ThreshY]);
            ResetY = ((obj.ResetVoltages(1,chan)+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
            set(obj.UIhandles.ResetLine(chan), 'YData', [ResetY,ResetY]);
        end
        function bits = Volts2Bits(obj, VoltVector, RangeIndexes)
            VoltVector = double(VoltVector);
            nElements = length(VoltVector);
            bits = zeros(1,nElements);
            for i = 1:nElements
                thisMultiplier = obj.RangeVoltageSpan(RangeIndexes(i));
                thisOffset = obj.RangeOffsets(RangeIndexes(i));
                bits(i) = ((VoltVector(i) + thisOffset)/thisMultiplier)*(obj.chBits-1);
            end
        end
        function ValueOut = ScaleValue(obj,Action,ValueIn,RangeString)
            
            %validate input: nrows in ValueIn == n values in Range
            BitWidth = obj.chBits-1;
            if obj.Info.HardwareVersion == 1
                BitWidth = 2^13;
            end
            ValueOut = nan(size(ValueIn));
            for i=1:size(ValueIn,1)
                thisRange = obj.RangeIndex(i);
                switch Action
                    case 'toVolts'
                        ValueOut(i,:) = double(ValueIn(i,:)) * obj.RangeVoltageSpan(thisRange)/BitWidth - obj.RangeOffsets(thisRange);
                    case 'toBits'
                        ValueOut(i,:) = uint32((ValueIn(i,:) + obj.RangeOffsets(thisRange)) * BitWidth/obj.RangeVoltageSpan(thisRange));
                end
            end
        end
        function stepTimescale(obj, Step)
            NewPos = obj.UIdata.TimeDivPos + Step;
            if (NewPos > 0) && (NewPos <= length(obj.UIdata.TimeDivValues))
                obj.UIdata.TimeDivPos = obj.UIdata.TimeDivPos + Step;
                newTimeDivValue = obj.UIdata.TimeDivValues(obj.UIdata.TimeDivPos);
                nSamplesPerSweep = obj.SamplingRate*newTimeDivValue*obj.UIhandles.nXDivisions;
                Interval = obj.UIhandles.nXDivisions/(nSamplesPerSweep-1);
                obj.UIdata.Xdata = 0:Interval:obj.UIhandles.nXDivisions;
                obj.UIdata.Ydata = nan(obj.nPhysicalChannels,nSamplesPerSweep);
                obj.UIdata.SweepPos = 1;
                for i = 1:obj.nPhysicalChannels
                    set(obj.UIhandles.OscopeDataLine(i), 'XData', [obj.UIdata.Xdata,obj.UIdata.Xdata], 'YData', [obj.UIdata.Ydata(i,:),obj.UIdata.Ydata(i,:)]);
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
        function stepVoltscale(obj, Step)
            NewPos = obj.UIdata.VoltDivPos + Step;
            if (NewPos > 0) && (NewPos <= length(obj.UIdata.VoltDivValues))
                obj.UIdata.VoltDivPos = obj.UIdata.VoltDivPos + Step;
                obj.UIdata.SweepPos = 1;
                obj.UIdata.Ydata = nan(obj.nPhysicalChannels,obj.UIdata.nDisplaySamples);
                NewVoltsDiv = obj.UIdata.VoltDivValues(NewPos);
                if NewVoltsDiv >= 1
                    voltString = ['V/div: ' num2str(NewVoltsDiv) '.0'];
                else
                    voltString = ['mV/div: ' num2str(NewVoltsDiv*1000) '.0'];
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
            ValidSF = 1;
            SFstring = get(obj.UIhandles.SFEdit, 'String');
            SF = str2double(SFstring);
            if ~isnan(SF)
                SF = round(SF);
                if (SF >= obj.Info.SamplingRateRange(1)) && (SF <= obj.Info.SamplingRateRange(2))
                    ValidSF = 1;
                end
            end
            if ValidSF == 1
                try
                    obj.SamplingRate = SF;
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
            EnableStrings = {'off', 'on'};
            set(obj.UIhandles.thresholdSet(chan), 'enable', EnableStrings{value+1});
            set(obj.UIhandles.resetSet(chan), 'enable', EnableStrings{value+1});
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
            ValidThreshold = 0;
            if ~isnan(newThreshold)
                if (newThreshold >= thisChannelMin) && (newThreshold <= thisChannelMax) && isreal(newThreshold)
                    obj.ResetVoltages(1,chan) = newThreshold;
                    ValidThreshold = 1;
                    obj.updateThresholdLine(chan);
                end
            end
            if ~ValidThreshold
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
                    NewData = obj.Port.read(nBytesToRead, 'uint8');
                    currentVoltDivValue = obj.UIdata.VoltDivValues(obj.UIdata.VoltDivPos);
                    Prefix = NewData(1);
                    if Prefix == 'R' || Prefix == '#'
                        Prefixes = NewData(1:nBytesPerFrame:end);
                        NewData(1:nBytesPerFrame:end) = [];
                        SyncData = NewData(1:nBytesPerFrame-1:end);
                        NewData(1:nBytesPerFrame-1:end) = []; % Spacer
                        NewSamples = typecast(NewData(1:end), 'uint16');
                        nNewSamples = length(NewSamples)/nChannelsStreaming;
                        SweepPos = obj.UIdata.SweepPos;
                        SyncPrefixes = (Prefixes == '#');
                        nSyncEvents = sum(SyncPrefixes);
                        SyncPrefixPositions = find(SyncPrefixes);
                        SampleDataForFile = zeros(nChannelsStreaming, nNewSamples);
                        for ch = 1:nChannelsStreaming
                            thisChIndex = updateChannels(ch);
                            NSThisCh = NewSamples(ch:nChannelsStreaming:end);
                            M = obj.RangeVoltageSpan(obj.RangeIndex(thisChIndex));
                            O = obj.RangeOffsets(obj.RangeIndex(thisChIndex));
                            NSThisChVolts = ((double(NSThisCh)/(obj.chBits-1))*M)-O;
                            if obj.USBstream2File
                                SampleDataForFile(ch,:) = NSThisChVolts;
                            end
                            MaxVolts = currentVoltDivValue*(obj.UIhandles.nYDivisions);
                            HalfMax = MaxVolts/2;
                            NSThisChVolts(NSThisChVolts<MaxVolts*-1 & NSThisChVolts>MaxVolts) = NaN;
                            NSThisChSamples = ((NSThisChVolts+HalfMax)/MaxVolts)*obj.UIhandles.nYDivisions;
                            if SweepPos == 1
                                obj.UIdata.Ydata(thisChIndex,:) = NaN;
                                obj.UIdata.Ydata(thisChIndex,1:nNewSamples) = NSThisChSamples;
                                obj.UIdata.SweepPos = SweepPos + nNewSamples;
                            elseif SweepPos + nNewSamples > obj.UIdata.nDisplaySamples
                                obj.UIdata.Ydata(thisChIndex,SweepPos:obj.UIdata.nDisplaySamples-1) = NSThisChSamples(1:(obj.UIdata.nDisplaySamples-SweepPos));
                                obj.UIdata.SweepPos = 1;
                            else
                                obj.UIdata.Ydata(thisChIndex,SweepPos:SweepPos+nNewSamples-1) = NSThisChSamples;
                                obj.UIdata.SweepPos = SweepPos + nNewSamples;
                            end
                            set(obj.UIhandles.OscopeDataLine(thisChIndex), 'Ydata', [obj.UIdata.Ydata(thisChIndex,:),obj.UIdata.Ydata(thisChIndex,:)]);
                        end
                        if obj.USBstream2File
                            obj.USBstreamFile.Samples(1:nChannelsStreaming,obj.USBFile_SamplePos:obj.USBFile_SamplePos+nNewSamples-1) = SampleDataForFile;
                        end
                        if nSyncEvents > 0
                            obj.USBstreamFile.SyncEvents(1,obj.USBFile_EventPos:obj.USBFile_EventPos+nSyncEvents-1) = double(SyncData(SyncPrefixes));
                            obj.USBstreamFile.SyncEventTimes(1,obj.USBFile_EventPos:obj.USBFile_EventPos+nSyncEvents-1) = double(SyncPrefixPositions + obj.USBFile_SamplePos - 1);
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