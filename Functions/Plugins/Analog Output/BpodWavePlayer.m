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
classdef BpodWavePlayer < handle
    properties
        Port % ArCOM Serial port
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
    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end
    properties (Access = private)
        CurrentFirmwareVersion = 1;
        ValidRanges = {'0V:5V', '0V:10V', '0V:12V', '-5V:5V', '-10V:10V', '-12V:12V'};
        TriggerModeStrings = {'Normal', 'Master', 'Toggle'};
        ValidBinaryStates = {'Off', 'On'};
        LoopModeLogic % Logic equivalent of LoopMode vector
        BpodEventsLogic % Logic equivalent of BpodEvents vector
        TriggerProfileLogic % Logic equivalent of TriggerProfileEnable vector
        ValidSamplingRates = [1 200000]; % Range of valid sampling rates
        WaveformsLoaded = zeros(1,256);
        isPlaying;
        maxSimultaneousChannels;
        nTriggerProfiles = 0;
        maxWaves; % Maximum number of waveforms to store on device
        nChannels; % Number of output channels
        Initialized = 0; % Set to 1 when initialized (to avoid spamming device with settings as fields are populated)
    end
    methods
        function obj = BpodWavePlayer(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write(227, 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 228
                error('Could not connect =( ')
            end
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.CurrentFirmwareVersion
                error(['Error: old firmware detected - v' obj.FirmwareVersion '. The current version is: ' obj.CurrentFirmwareVersion '. Please update the I2C messenger firmware using Arduino.'])
            end
            obj.Port.write('N', 'uint8');
            obj.nChannels = obj.Port.read(1, 'uint8');
            obj.maxWaves = obj.Port.read(1, 'uint16');
            triggerModeIndex = obj.Port.read(1, 'uint8')+1;
            obj.TriggerProfileLogic = obj.Port.read(1, 'uint8');
            obj.nTriggerProfiles = obj.Port.read(1, 'uint8');
            RangeIndex = obj.Port.read(1, 'uint8')+1;
            SamplingPeriodMicroseconds = typecast(obj.Port.read(4, 'uint8'), 'single');
            obj.BpodEventsLogic = obj.Port.read(obj.nChannels, 'uint8');
            obj.LoopModeLogic = obj.Port.read(obj.nChannels, 'uint8');
            loopDurationSamples =  obj.Port.read(obj.nChannels, 'uint32');
            obj.Waveforms = cell(1,obj.maxWaves); % Local copy of currently loaded waveforms
            obj.isPlaying = zeros(1,obj.nChannels);
            obj.maxSimultaneousChannels = obj.nChannels;
            obj.TriggerProfiles = zeros(obj.nTriggerProfiles, obj.nChannels);
            obj.TriggerProfileEnable = obj.ValidBinaryStates{obj.TriggerProfileLogic+1};
            obj.TriggerMode = obj.TriggerModeStrings{triggerModeIndex};
            obj.OutputRange = obj.ValidRanges{RangeIndex};
            obj.SamplingRate = 1/(SamplingPeriodMicroseconds/1000000);
            obj.LoopDuration = single(loopDurationSamples)*single(obj.SamplingRate);
            obj.LoopMode = obj.ValidBinaryStates(obj.LoopModeLogic+1);
            obj.BpodEvents = obj.ValidBinaryStates(obj.BpodEventsLogic+1);
            obj.Initialized = 1;
        end
        function set.TriggerMode(obj, mode)
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
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting trigger mode. Confirm code not returned.');
            end
            obj.TriggerMode = mode;
        end
        function set.BpodEvents(obj,Events)
            nEvents = length(Events);
            if nEvents ~= obj.nChannels
                error('Error setting Bpod Events: one status must be given for each channel - i.e. if 4 channels, {''Off'', ''On'', ''Off'', ''Off''}');
            end
            BpodEvents = zeros(1,nEvents);
            for i = 1:nEvents
                if strcmp(lower(Events{i}), 'on')
                    BpodEvents(i) = 1;
                elseif strcmp(lower(Events{i}), 'off')
                    BpodEvents(i) = 0;
                else
                    error('Error setting Bpod Events: status of each channel must be either ''On'' or ''Off''');
                end
            end
            obj.Port.write(['V' BpodEvents], 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting Bpod events. Confirm code not returned.');
            end
            obj.BpodEvents = Events;
            obj.BpodEventsLogic = BpodEvents;
        end
        function set.LoopMode(obj, Modes)
            if obj.Initialized
                LoopModes = zeros(1,obj.nChannels);
                for i = 1:obj.nChannels
                    if strcmp(lower(Modes{i}), 'on')
                        if obj.LoopDuration(i) == 0
                            error('Error: before enabling loop mode, each enabled channel must have a valid loop duration.')
                        end
                        LoopModes(i) = 1;
                    elseif strcmp(lower(Modes{i}), 'off')
                        LoopModes(i) = 0;
                    else
                        error('Error setting loop mode: status of each channel must be either ''On'' or ''Off''');
                    end
                end
                obj.Port.write(['O' LoopModes], 'uint8', obj.LoopDuration*obj.SamplingRate, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting loop mode. Confirm code not returned.');
                end
                obj.LoopModeLogic = LoopModes;
            end
            obj.LoopMode = Modes; 
        end
        function set.LoopDuration(obj, Durations)
            if obj.Initialized
                if length(Durations) ~= obj.nChannels
                    error('Error setting loop durations - one duration must be set for each channel.')
                end
                obj.Port.write(['O' obj.LoopModeLogic], 'uint8', Durations*obj.SamplingRate, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting loop duration. Confirm code not returned.');
                end
            end
            obj.LoopDuration = Durations;
            
        end
        function set.TriggerProfileEnable(obj, triggerProfileState)
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
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting trigger profile enable. Confirm code not returned.');
                end
            end
            obj.TriggerProfileEnable = triggerProfileState;
            
        end
        function set.TriggerProfiles(obj, profileMatrix)
            [length, width] = size(profileMatrix);
            if (length ~= obj.nTriggerProfiles) || (width ~= obj.nChannels)
                error(['Error setting trigger profiles: matrix of trigger profiles must be ' num2str(obj.nTriggerProfiles) ' profiles X ' num2str(nChannels) ' channels.'])
            end
            if sum(sum((profileMatrix > 0)') > obj.maxSimultaneousChannels) > 0
                error(['Error setting trigger profiles: the current sampling rate only allows ' num2str(obj.maxSimultaneousChannels) ' channels to be triggered simultaneously. Your profile matrix contains at least 1 profile with too many channels.']);
            end
            profileMatrixOut = profileMatrix;
            profileMatrixOut(profileMatrixOut == 0) = 256;
            obj.Port.write(['F' profileMatrixOut(1:end)-1], 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting trigger profiles. Confirm code not returned.');
            end
            obj.TriggerProfiles = profileMatrix;
        end
        function set.OutputRange(obj, range)
            RangeIndex = find(strcmp(range, obj.ValidRanges));
            if isempty(RangeIndex)
                VR = [];
                for i = 1:length(obj.ValidRanges)
                    VR = [VR obj.ValidRanges{i} ' '];
                end
                error(['Invalid range specified: ' range '. Valid ranges are: ' VR]);
            end
            % Check to make sure all waves in "Waveforms" are within range
            switch RangeIndex
                case 1
                    Min = 0; Max = 5;
                case 2
                    Min = 0; Max = 10;
                case 3
                    Min = 0; Max = 12;
                case 4
                    Min = -5; Max = 5;
                case 5
                    Min = -10; Max = 10;
                case 6
                    Min = -12; Max = 12;
            end
            nWaveforms = length(obj.Waveforms);
            waveformErrors = [];
            for i = 1:nWaveforms
                if ~isempty(obj.Waveforms{i})
                    if (min(obj.Waveforms{i}) < Min) || (max(obj.Waveforms{i}) > Max)
                        waveformErrors = [waveformErrors i];
                    end
                end
            end
            if ~isempty(waveformErrors)
                error(['Error: Some loaded waves contain voltages out of range. Replace waveform# ' num2str(waveformErrors)]);
            end
            obj.Port.write(['R' RangeIndex-1], 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting output range. Confirm code not returned.');
            end
            obj.OutputRange = range;
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
            if obj.Initialized
                if sf < obj.ValidSamplingRates(1) || sf > obj.ValidSamplingRates(2)
                    error(['Error setting sampling rate: valid rates are in range: [' num2str(obj.ValidSamplingRates) '] Hz'])
                end
                SamplingPeriodMicroseconds = (1/sf)*1000000;
                obj.Port.write(['S' typecast(single(SamplingPeriodMicroseconds), 'uint8')], 'uint8');
                
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
                if sum(obj.LoopModeLogic) > 0 % Re-compute loop durations (in units of samples)
                    obj.Port.write(['O' obj.LoopModeLogic], 'uint8', obj.LoopDuration*sf, 'uint32'); % Update loop durations
                    Confirmed = obj.Port.read(1, 'uint8');
                end
            end
            obj.SamplingRate = sf;
        end
        function loadWaveform(obj, WaveIndex, Waveform)
            nSamples = length(Waveform);
            PositiveOnly = 0;
            switch obj.OutputRange
                case '0V:5V'
                    PositiveOnly = 1;
                    VoltageWidth = 5;
                case '0V:10V'
                    PositiveOnly = 1;
                    VoltageWidth = 10;
                case '0V:12V'
                    PositiveOnly = 1;
                    VoltageWidth = 12;
                case '-5V:5V'
                    VoltageWidth = 10;
                case '-10V:10V'
                    VoltageWidth = 20;
                case '-12V:12V'
                    VoltageWidth = 24;
            end
            minWave = min(Waveform);
            maxWave = max(Waveform);
            maxRange = VoltageWidth+(PositiveOnly*0.5);
            minRange = ((VoltageWidth/2)*-1) * (1-PositiveOnly);
            if ((minWave < minRange) || (maxWave > maxRange))
                error(['Error setting waveform: All voltages must be within the current range: ' obj.OutputRange '.'])
            end
            Offset = (VoltageWidth/2)*(1-PositiveOnly);
            WaveBits = ceil(((Waveform+Offset)/VoltageWidth)*(2^(16)-1));
            obj.Port.write(['L' WaveIndex-1], 'uint8', nSamples, 'uint32', WaveBits, 'uint16');
            Confirmed = obj.Port.read(1, 'uint8');
            obj.Waveforms{WaveIndex} = Waveform;
            obj.WaveformsLoaded(WaveIndex) = 1;
        end
        function setupSDCard(obj)
            disp('Preparing SD card. This may take up to 1 minute. Please wait.')
            obj.Port.write('Y', 'uint8');
            while obj.Port.bytesAvailable == 0
                pause(.001);
            end
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error clearing data. Confirm code not returned.');
            end
            disp('SD Card setup complete.')
        end
        function play(obj, varargin) % Play a waveform immediately on specified channel(s)
            if strcmpi(obj.TriggerProfileEnable, 'on')
                ProfileNum = varargin{1};
                if sum(obj.TriggerProfiles(ProfileNum,:)) == 0
                    error(['Error: Trigger profile# ' num2str(ProfileNum) ' not defined.'])
                end
                obj.Port.write(['P' ProfileNum-1], 'uint8');
            else
                Channels = varargin{1};
                WaveIndex = varargin{2};
                if ~obj.WaveformsLoaded(WaveIndex)
                    error(['Error: waveform #' num2str(WaveIndex) ' must be loaded with loadWaveform() before it can be triggered.'])
                end
                if length(Channels) > obj.maxSimultaneousChannels
                    error(['Error: cannot trigger more than ' num2str(obj.maxSimultaneousChannels) ' simultaneous channel(s) at the current sampling rate.'])
                end
                ChannelBits = 0; % Channels to trigger are read as bits
                for i = 1:length(Channels)
                    ChannelBits = ChannelBits + 2^(Channels(i)-1);
                end
                obj.Port.write(['P' ChannelBits WaveIndex-1], 'uint8');
            end
        end
        function stop(obj)
            obj.Port.write('X', 'uint8');
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end