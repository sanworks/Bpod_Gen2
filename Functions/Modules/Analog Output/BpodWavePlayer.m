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

% BpodWavePlayer is a class to interface with the Bpod Analog Output Module
% via its USB connection to the PC. The Analog Output module must have
% WavePlayer firmware installed. Firmware can be swapped with LoadBpodFirmware().
%
% User-configurable device parameters are exposed as class properties. Setting
% the value of a property will trigger its 'set' method to update the device.
%
% Docs:
% https://sanworks.github.io/Bpod_Wiki/module-documentation/waveplayer/
% Additional documentation of properties and methods is given in-line below.
%
% Example usage:
% W = BpodWavePlayer('COM3'); % Create an instance of BpodWavePlayer,
%                         connecting to the Analog Output Module on port COM3
% W.SamplingRate = 100000; % Set the sampling rate to 100kHz
% myWaveform = GenerateSineWave(100000, 1000, 1); % Generate a 1-second 1kHz pure tone sampled at 100kHz
% W.loadWaverform(2, myWaveform); % Load myWaveform to the WavePlayer module at position 2
% W.play([1 3], 2); % Play waveform 2 on output channels 1 and 3
% clear W; % clear the object from the workspace, releasing the USB serial port

classdef BpodWavePlayer < handle
    properties
        Port % ArCOM Serial port
        Info % A struct containing information about the connected hardware
        SamplingRate % 1Hz-50kHz, affects all channels
        OutputRange % Voltage output range for all channels: '0V:5V', '0V:10V', '0V:12V', '-5V:5V', '-10V:10V', '-12V:12V'
        % For best signal quality, use the smallest range necessary for your application.
        Waveforms % Local copy of all waveforms loaded to microSD
        TriggerMode % 'Normal' plays the triggered wave(s), and ignores triggers on the same channel during playback.
        % 'Master' plays the triggered wave(s), and triggers can force-start a new wave during playback.
        % 'Toggle' plays the triggered wave(s), and stops playback if the same wave is triggered again.
        TriggerProfileEnable % 'Off' = trigger byte -> bits corresponding to channels, and a waveform index byte is sent.
        % 'On' = trigger byte specifies trigger profile to play. Each trigger profile is a
        % list of waveforms to play on each channel.
        TriggerProfiles % A list of waveforms to play on each channel.
        LoopMode % 'On' loops the waveform until LoopDuration seconds, or until toggled off. 'Off' = one shot.
        LoopDuration % (seconds) In loop mode, specifies the duration to loop the waveform following a trigger.
        BpodEvents % 'On' sends byte 0x(channel) when starting playback, and 0x(channel+4) when playback finishes.
    end
    properties (Access = private)
        CurrentFirmwareVersion = 6;
        ValidRanges = {'0V:5V', '0V:10V', '0V:12V', '-5V:5V', '-10V:10V', '-12V:12V'};
        TriggerModeStrings = {'Normal', 'Master', 'Toggle'};
        ValidBinaryStates = {'Off', 'On'};
        LoopModeLogic % Logic equivalent of LoopMode vector
        BpodEventsLogic % Logic equivalent of BpodEvents vector
        TriggerProfileLogic % Logic equivalent of TriggerProfileEnable vector
        ValidSamplingRates = [1 200000]; % Range of valid sampling rates
        WaveformsLoaded = zeros(1,256);
        maxSimultaneousChannels; % Maximum number of channels that can be triggered at the current sampling rate
        nTriggerProfiles = 0; % Number of trigger profiles available on the connected device
        maxWaves; % Maximum number of waveforms that can be stored on the connected device
        nChannels; % Number of output channels on the connected device
        Initialized = 0; % Set to 1 when initialized (to avoid spamming device with settings as fields are populated)
    end
    methods
        function obj = BpodWavePlayer(portString, varargin)
            % Constructor
            showWarnings = 1;
            if nargin > 1
                if strcmp(varargin{1}, 'NoWarnings')
                    showWarnings = 0;
                end
            end

            % Connect to USB Serial port
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write(227, 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 228
                error('Could not connect =( ')
            end

            % Read and verify firmware version
            obj.Info.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.Info.FirmwareVersion < obj.CurrentFirmwareVersion  
                if showWarnings == 1
                    disp('*********************************************************************');
                    disp(['Warning: Old firmware detected: v' num2str(obj.Info.FirmwareVersion) ...
                        '. The current version is: v' num2str(obj.CurrentFirmwareVersion) char(13)...
                        'Please clear the BpodWavePlayer and update with: LoadBpodFirmware().'])
                    disp('*********************************************************************');
                end
            end

            % Read hardware information
            obj.Info.HardwareVersion = NaN;
            obj.Info.CircuitRevision = NaN;
            if obj.Info.FirmwareVersion > 4
                obj.Port.write('H', 'uint8');
                obj.Info.HardwareVersion = obj.Port.read(1, 'uint8');
                obj.Info.CircuitRevision = obj.Port.read(1, 'uint8');
            end
            
            obj.Port.write('N', 'uint8');
            obj.nChannels = obj.Port.read(1, 'uint8');
            obj.maxWaves = obj.Port.read(1, 'uint16');
            if obj.Info.FirmwareVersion < 6
                obj.Port.read(2,'uint8'); % Older firmware returned parameters here, which will
                                          % be overwritten in the call to set2Defaults() below
            end
            obj.nTriggerProfiles = obj.Port.read(1, 'uint8');

            if obj.Info.FirmwareVersion < 6
                pause(.2);
                obj.Port.flush(); % Older firmware returned parameters here, which will
                                  % be overwritten in the call to set2Defaults() below
                obj.LoopModeLogic = zeros(1, obj.nChannels); % Older firmware required initial 
                                                        % values for LoopModeLogic and LoopDuration
                obj.LoopDuration = zeros(1, obj.nChannels);
            end

            % Setup parameters
            obj.Waveforms = cell(1,obj.maxWaves); % Local copy of currently loaded waveforms
            obj.maxSimultaneousChannels = obj.nChannels;
            obj.Initialized = 1;
            obj.set2Defaults;
        end

        function set.TriggerMode(obj, mode)
            % Set trigger mode
            % Parameters = mode (char array), 'normal', 'master' or 'toggle'

            switch lower(mode)
                case 'normal'
                    modeByte = 0;
                case 'master'
                    modeByte = 1;
                case 'toggle'
                    modeByte = 2;
                otherwise
                    error(['Invalid trigger mode: ' mode '. Valid modes are: Normal, Master, Toggle.'])
            end
            obj.Port.write(['T' modeByte], 'uint8');
            obj.confirmTransmission('setting trigger mode');
            obj.TriggerMode = mode;
        end

        function set.BpodEvents(obj, events)
            % Enable/Disable behavior events indicating when waveforms are played on each channel
            % Arguments: events, a 1xnChannels cell array of strings indicating 'on' or 'off' for each analog output channel.

            nEvents = length(events);
            if nEvents ~= obj.nChannels
                error(['Error setting Bpod Events: one status must be given for each channel - ' ...
                       'i.e. if 4 channels, {''Off'', ''On'', ''Off'', ''Off''}']);
            end
            bpodEvents = zeros(1,nEvents);
            for i = 1:nEvents
                if strcmp(lower(events{i}), 'on')
                    bpodEvents(i) = 1;
                elseif strcmp(lower(events{i}), 'off')
                    bpodEvents(i) = 0;
                else
                    error('Error setting Bpod Events: status of each channel must be either ''On'' or ''Off''');
                end
            end
            obj.Port.write(['V' bpodEvents], 'uint8');
            obj.confirmTransmission('setting enable/disable Bpod events');
            obj.BpodEvents = events;
            obj.BpodEventsLogic = bpodEvents;
        end

        function set.LoopMode(obj, modes)
            % Set loop mode on or off
            % Arguments: modes, a 1xnChannels cell array of strings indicating 'on' or 'off' for each analog output channel.

            if obj.Initialized
                loopModes = zeros(1,obj.nChannels);
                for i = 1:obj.nChannels
                    if strcmp(lower(modes{i}), 'on')
                        if obj.LoopDuration(i) == 0
                            error('Error: before enabling loop mode, each enabled channel must have a valid loop duration.')
                        end
                        loopModes(i) = 1;
                    elseif strcmp(lower(modes{i}), 'off')
                        loopModes(i) = 0;
                    else
                        error('Error setting loop mode: status of each channel must be either ''On'' or ''Off''');
                    end
                end
                if obj.Info.FirmwareVersion > 5
                    obj.Port.write(['O' loopModes], 'uint8');
                else
                    obj.Port.write(['O' loopModes], 'uint8', obj.LoopDuration*obj.SamplingRate, 'uint32');
                end
                obj.confirmTransmission('setting loop mode');
                obj.LoopModeLogic = loopModes;
            end
            obj.LoopMode = modes; 
        end

        function set.LoopDuration(obj, durations)
            % For loop mode, set the loop duration
            % Arguments: Durations (s) for which to loop the loaded waveform on trigger.

            if obj.Initialized
                if length(durations) ~= obj.nChannels
                    error('Error setting loop durations - one duration must be set for each channel.')
                end
                if obj.Info.FirmwareVersion > 5
                    obj.Port.write('D', 'uint8', durations*obj.SamplingRate, 'uint32');
                else
                    obj.Port.write(['O' obj.LoopModeLogic], 'uint8', durations*obj.SamplingRate, 'uint32');
                end
                obj.confirmTransmission('setting loop duration');
            end
            obj.LoopDuration = durations;
            
        end

        function set.TriggerProfileEnable(obj, triggerProfileState)
            % Enable/Disable trigger profile mode
            % Arguments: triggerProfileState, a 1xnChannels cell array of strings indicating 'on' or 'off' for each analog output channel.

            if obj.Initialized
                switch lower(triggerProfileState)
                    case 'off'
                        profileEnableByte = 0;
                    case 'on'
                        profileEnableByte = 1;
                    otherwise
                        error(['Invalid value for TriggerProfileEnable: ' triggerProfileState '. Valid values are: Off, On.'])
                end
                obj.Port.write(['B' profileEnableByte], 'uint8');
                obj.confirmTransmission('setting trigger profile mode');
            end
            obj.TriggerProfileEnable = triggerProfileState;
            
        end

        function set.TriggerProfiles(obj, profileMatrix)
            % Set up trigger profiles. Each profile is a list of waveforms to play on each channel 
            % when the profile index is triggered with the 'P' command.
            % Arguments: profileMatrix, a nTriggerProfiles x nChannels matrix. Each row is a trigger profile, specifying which
            % waveform to play on each channel.

            [length, width] = size(profileMatrix);
            if (length ~= obj.nTriggerProfiles) || (width ~= obj.nChannels)
                error(['Error setting trigger profiles: matrix of trigger profiles must be ' num2str(obj.nTriggerProfiles)... 
                       ' profiles X ' num2str(obj.nChannels) ' channels.'])
            end
            if sum(sum((profileMatrix > 0)') > obj.maxSimultaneousChannels) > 0
                error(['Error setting trigger profiles: the current sampling rate only allows '... 
                    num2str(obj.maxSimultaneousChannels)... 
                    ' channels to be triggered simultaneously. Your profile matrix has at least 1 profile with too many channels.']);
            end
            profileMatrixOut = profileMatrix;
            profileMatrixOut(profileMatrixOut == 0) = 256;
            obj.Port.write(['F' profileMatrixOut(1:end)-1], 'uint8');
            obj.confirmTransmission('setting trigger profiles');
            obj.TriggerProfiles = profileMatrix;
        end

        function set.OutputRange(obj, newRange)
            % Set the output range for the device (affects all channels)
            % Arguments: range, a char array indicating the selected range.

            rangeIndex = find(strcmp(newRange, obj.ValidRanges));
            if isempty(rangeIndex)
                vr = [];
                for i = 1:length(obj.ValidRanges)
                    vr = [vr obj.ValidRanges{i} ' '];
                end
                error(['Invalid range specified: ' newRange '. Valid ranges are: ' vr]);
            end
            % Check to make sure all waves in "Waveforms" are within range
            switch rangeIndex
                case 1
                    minRange = 0; maxRange = 5;
                case 2
                    minRange = 0; maxRange = 10;
                case 3
                    minRange = 0; maxRange = 12;
                case 4
                    minRange = -5; maxRange = 5;
                case 5
                    minRange = -10; maxRange = 10;
                case 6
                    minRange = -12; maxRange = 12;
            end
            nWaveforms = length(obj.Waveforms);
            waveformErrors = [];
            for i = 1:nWaveforms
                if ~isempty(obj.Waveforms{i})
                    if (min(obj.Waveforms{i}) < minRange) || (max(obj.Waveforms{i}) > maxRange)
                        waveformErrors = [waveformErrors i];
                    end
                end
            end
            if ~isempty(waveformErrors)
                error(['Error: Some loaded waves contain voltages out of range. Replace waveform# ' num2str(waveformErrors)]);
            end
            obj.Port.write(['R' rangeIndex-1], 'uint8');
            obj.confirmTransmission('setting output range');
            obj.OutputRange = newRange;

            % Re-load all waveforms with new bit coding
            if sum(cellfun(@isempty, obj.Waveforms)) ~= length(obj.Waveforms)
                disp('Updating all waveforms on output device, coded for new range. Please wait.')
                for i = 1:nWaveforms
                    if ~isempty(obj.Waveforms{i})
                        obj.loadWaveform(i, obj.Waveforms{i});
                    end
                end
                disp('Waveforms updated.')
            end
        end

        function set.SamplingRate(obj, sf)
            % Set the sampling rate (affects all channels)
            % Arguments: sf, the sampling rate (Hz)

            if obj.Initialized
                if sf < obj.ValidSamplingRates(1) || sf > obj.ValidSamplingRates(2)
                    error(['Error setting sampling rate: valid rates are in range: [' num2str(obj.ValidSamplingRates) '] Hz'])
                end
                samplingPeriodMicroseconds = (1/sf)*1000000;
                obj.Port.write(['S' typecast(single(samplingPeriodMicroseconds), 'uint8')], 'uint8');
                if obj.Info.FirmwareVersion > 5
                    obj.confirmTransmission('setting sampling rate');
                end
                if obj.Info.HardwareVersion < 2
                    if sf > 100000
                        obj.maxSimultaneousChannels = 1;
                    elseif sf > 75000
                        obj.maxSimultaneousChannels = 2;
                    elseif sf > 50000
                        obj.maxSimultaneousChannels = 3;
                    elseif sf > 30000
                        obj.maxSimultaneousChannels = 4;
                    else
                        obj.maxSimultaneousChannels = 8;
                    end
                end
                if sum(obj.LoopModeLogic) > 0 % Re-compute loop durations (in units of samples)
                    obj.Port.write('D', 'uint8', obj.LoopDuration*sf, 'uint32'); % Update loop durations
                    obj.confirmTransmission('setting sampling rate');
                end
            end
            obj.SamplingRate = sf;
        end

        function set2Defaults(obj)
            % Return all user parameters to default

            obj.SamplingRate = 10000;
            obj.OutputRange = '-5V:5V';
            obj.TriggerMode = 'Normal';
            obj.TriggerProfileEnable = 'Off';
            obj.TriggerProfiles = zeros(obj.nTriggerProfiles, obj.nChannels);
            obj.LoopMode = repmat({'Off'}, 1, obj.nChannels);
            obj.LoopDuration = zeros(1, obj.nChannels);
            obj.BpodEvents = repmat({'Off'}, 1, obj.nChannels);
        end

        function loadWaveform(obj, waveIndex, waveform)
            % Load a waveform to the device at a specified index
            % Arguments: 
            % waveIndex: the index to load to (up to 64 waveforms)
            % waveform: a 1xnSamples vector of voltages
            
            nSamples = length(waveform);
            waveBits = obj.volts2Bits(waveform);
            obj.Port.write(['L' waveIndex-1], 'uint8', nSamples, 'uint32', waveBits, 'uint16');
            obj.confirmTransmission('loading waveform');
            obj.Waveforms{waveIndex} = waveform;
            obj.WaveformsLoaded(waveIndex) = 1;
        end

        function bits = volts2Bits(obj, volts)
            % Convert volts to DAC bits

            positiveOnly = 0;
            switch obj.OutputRange
                case '0V:5V'
                    positiveOnly = 1;
                    voltageWidth = 5;
                case '0V:10V'
                    positiveOnly = 1;
                    voltageWidth = 10;
                case '0V:12V'
                    positiveOnly = 1;
                    voltageWidth = 12;
                case '-5V:5V'
                    voltageWidth = 10;
                case '-10V:10V'
                    voltageWidth = 20;
                case '-12V:12V'
                    voltageWidth = 24;
            end
            minVolts = min(volts);
            maxVolts = max(volts);
            maxRange = (voltageWidth/2)+(positiveOnly*(voltageWidth/2));
            minRange = ((voltageWidth/2)*-1) * (1-positiveOnly);
            if ((minVolts < minRange) || (maxVolts > maxRange))
                error(['Error converting volts to bits: All voltages must be within the current range: ' obj.OutputRange '.'])
            end
            offset = (voltageWidth/2)*(1-positiveOnly);
            bits = ceil(((volts+offset)/voltageWidth)*(2^(16)-1));
        end
        
        function setupSDCard(obj)
            % Setup the microSD card

            disp('Preparing SD card. This may take up to 1 minute. Please wait.')
            obj.Port.write('Y', 'uint8');
            while obj.Port.bytesAvailable == 0
                pause(.001);
            end
            obj.confirmTransmission('clearing data');
            disp('SD Card setup complete.')
        end

        function play(obj, varargin) 
            % Play a waveform immediately on specified channel(s)

            if strcmpi(obj.TriggerProfileEnable, 'on')
                profileNum = varargin{1};
                if sum(obj.TriggerProfiles(profileNum,:)) == 0
                    error(['Error: Trigger profile# ' num2str(profileNum) ' not defined.'])
                end
                obj.Port.write(['P' profileNum-1], 'uint8');
            else
                if nargin > 2
                    channels = varargin{1};
                    waveIndex = varargin{2};
                    if ~obj.WaveformsLoaded(waveIndex)
                        error(['Error: waveform #' num2str(waveIndex) ' must be loaded with loadWaveform() before it can be triggered.'])
                    end
                    if length(channels) > obj.maxSimultaneousChannels
                        error(['Error: cannot trigger more than ' num2str(obj.maxSimultaneousChannels)... 
                            ' simultaneous channel(s) at the current sampling rate.'])
                    end
                    channelBits = 0; % Channels to trigger are read as bits
                    for i = 1:length(channels)
                        channelBits = channelBits + 2^(channels(i)-1);
                    end
                    obj.Port.write(['P' channelBits waveIndex-1], 'uint8');
                else
                    if obj.Info.FirmwareVersion > 4
                        waveList = varargin{1};
                        if length(waveList) ~= obj.nChannels
                            error(['When using syntax W.play([List of waveform indexes]) the list must ' ...
                                   'include one waveform for each channel. Use 0 for no waveform.'])
                        end
                        waves2Trigger = waveList(waveList > 0);
                        if sum(obj.WaveformsLoaded(waves2Trigger) == 0) > 0
                            firstWaveNotLoaded = find(obj.WaveformsLoaded(waves2Trigger) == 0, 1);
                            error(['Waveform #' num2str(waves2Trigger(firstWaveNotLoaded))... 
                                ' must be loaded with loadWaveform() before it can be triggered.'])
                        end
                        if length(waves2Trigger) > obj.maxSimultaneousChannels
                            error(['Cannot trigger more than ' num2str(obj.maxSimultaneousChannels)... 
                                ' simultaneous channel(s) at the current sampling rate.'])
                        end
                        waveList(waveList == 0) = 255;
                        obj.Port.write(['>' waveList-1], 'uint8');
                    else
                        error('WavePlayer must have firmware v5 or newer to trigger multiple channels without using trigger profile mode.')
                    end
                end
            end
        end

        function stop(obj)
            % Stop all currently playing waveforms

            obj.Port.write('X', 'uint8');
        end

        function setFixedOutput(obj, channels, dacOutputBits) 
            % Set a fixed voltage on a channel by setting DAC bits. See setFixedVoltage() below for a more straightforward
            % implementation
            % Arguments:
            % channels, a list of channels to set. 
            % dacOutputBits range from 0-65535, mapped to current output range

            if obj.Info.FirmwareVersion < 5
                error('Error: Setting a fixed output value now requires firmware v5. All 8 output channels are now supported.')
            end
            channelBits = 0;
            for i = 1:length(channels)
                channelBits = channelBits + 2^(channels(i)-1);
            end
            obj.Port.write(['!' channelBits], 'uint8', dacOutputBits, 'uint16');
            obj.confirmTransmission('setting fixed output voltage(s)');
        end

        function setFixedVoltage(obj, channels, voltage)
            % Set a fixed voltage on output channel(s)

            dacOutputBits = obj.volts2Bits(voltage);
            obj.setFixedOutput(channels, dacOutputBits);
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
                error(['Error ' opName ': the module denied your request.'])
            elseif confirmed ~= 1
                error(['Error ' opName ': module did not acknowledge the operation.']);
            end
        end
    end
end