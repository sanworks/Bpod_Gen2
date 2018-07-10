%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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
classdef BpodAudioPlayer < handle
    properties
        Info % Information about the connected audio player
        Port % ArCOM Serial port
        SamplingRate % 1Hz-100kHz, affects all channels
        LoadMode % 'Fast' to load sounds fast (potentially disrupting playback) or 'Safe' to load slower, but playback-safe
        Waveforms % Local copy of all waveforms loaded to microSD
        TriggerMode % 'Normal' plays the triggered wave(s), and ignores triggers on the same channel during playback.
        % 'Master' plays the triggered wave(s), and triggers can force-start a new wave during playback.
        % 'Toggle' plays the triggered wave(s), and stops playback if the same wave is triggered again.
        LoopMode %For each wave, 'On' loops the waveform until LoopDuration seconds, or until toggled off. 'Off' = one shot.
        LoopDuration % (seconds) In loop mode, specifies the duration to loop the waveform following a trigger. 0 = until canceled.
        AMenvelope % If defined, a vector of amplitude coefficients for each waveform on onest + offset (in reverse)
        BpodEvents % 'On' sends byte 0x(channel) when starting playback, and 0x(channel+4) when playback finishes.
    end
    properties (SetAccess = protected)
        FirmwareVersion = 0;
    end
    properties (Access = private)
        CurrentFirmwareVersion = 2;
        TriggerModeStrings = {'Normal', 'Master', 'Toggle'};
        ValidBinaryStates = {'Off', 'On'};
        BpodEventsLogic % Logic equivalent of BpodEvents vector
        WaveformsLoaded = zeros(1,256);
        OutputRange = [-5 5]; % Range of sample voltages allowed
        isPlaying;
        maxSamplingRate; % In Hz
        playerType; % 0 = standard firmware, 1 = live firmware (see wiki)
        playerTypeStrings = {'AudioPlayer Standard', 'AudioPlayer Live'};
        ValidLoadModes;
        maxEnvelopeSamples; % Maximum number of samples in the AM envelope
        maxWaves; % Maximum number of waveforms to store on device
        LoadOp = 'L';
        Initialized = 0; % Set to 1 when initialized (to avoid spamming device with settings as fields are populated)
    end
    methods
        function obj = BpodAudioPlayer(portString, varargin)
            ShowWarnings = 1;
            if nargin > 1
                if strcmp(varargin{1}, 'NoWarnings')
                    ShowWarnings = 0;
                end
            end
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write(229, 'uint8');
            response = obj.Port.read(1, 'uint8');
            if response ~= 230
                error('Could not connect =( ')
            end
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.CurrentFirmwareVersion
                if ShowWarnings == 1
                    disp('*********************************************************************');
                    disp(['Warning: Old firmware detected: v' num2str(obj.FirmwareVersion) ...
                        '. The current version is: v' num2str(obj.CurrentFirmwareVersion) char(13)...
                        'Please update using the firmware update tool: UpdateBpodFirmware().'])
                    disp('*********************************************************************');
                end
            end
            obj.Port.write('N', 'uint8');
            obj.playerType = obj.Port.read(1, 'uint8');
            obj.Info.playerType = obj.playerTypeStrings{obj.playerType+1};
            obj.maxWaves = obj.Port.read(1, 'uint16');
            obj.maxEnvelopeSamples = obj.Port.read(1, 'uint16');
            obj.maxSamplingRate = double(obj.Port.read(1, 'uint32'));
            obj.Info.maxSamplingRate = obj.maxSamplingRate;
            triggerModeIndex = 1;
            SamplingPeriodMicroseconds = single(22.675737);
            obj.BpodEventsLogic = 0;
            obj.LoopMode = logical(zeros(1,obj.maxWaves));
            loopDurationSamples =  zeros(1,obj.maxWaves);
            obj.Waveforms = cell(1,obj.maxWaves); % Local copy of currently loaded waveforms
            obj.isPlaying = 0;
            obj.LoadMode = 'Fast';
            if obj.playerType == 0
                obj.ValidLoadModes = {'Fast'};
            else
                obj.ValidLoadModes = {'Fast', 'Safe'};
            end
            obj.TriggerMode = obj.TriggerModeStrings{triggerModeIndex};
            obj.SamplingRate = 1/(SamplingPeriodMicroseconds/1000000);
            obj.LoopDuration = single(loopDurationSamples)*single(obj.SamplingRate);
            obj.BpodEvents = obj.ValidBinaryStates{obj.BpodEventsLogic+1};
            obj.AMenvelope = [];
            obj.Initialized = 1;
            obj.Info.maxSounds = obj.maxWaves;
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
        function set.LoadMode(obj,Mode)
            switch Mode
                case 'Fast'
                    obj.LoadOp = 'L';
                case 'Safe'
                    if obj.playerType == 0
                        error('Error: Safe loading is not supported with AudioPlayer standard. Use AudioPlayerLive firmware.')
                    else
                        obj.LoadOp = '>';
                    end
                otherwise
                    error(['Error: ' Mode ' is not a valid load mode. Valid modes are: ''Fast'', ''Safe'''])
            end
            obj.LoadMode = Mode;
        end
        function set.BpodEvents(obj,Events)
            if strcmpi(Events, 'on')
                BpodEvents = 1;
            elseif strcmpi(Events, 'off')
                BpodEvents = 0;
            else
                error('Error setting Bpod Events: status must be either ''On'' or ''Off''');
            end
            obj.Port.write(['V' BpodEvents], 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting Bpod events. Confirm code not returned.');
            end
            obj.BpodEventsLogic = BpodEvents;
            obj.BpodEvents = Events;
        end
        function set.LoopMode(obj, LoopModes)
            if obj.Initialized
                if length(LoopModes) ~= obj.maxWaves
                    error('Error setting loop modes - a loop mode must exist for each wave.')
                end
                if ~islogical(LoopModes)
                    if sum(LoopModes > 1)>0 || (sum(LoopModes < 0))>0
                        error('Error: LoopModes must be 0 (looping disabled) or 1 (looping enabled)')
                    end
                end
                obj.Port.write(['O' uint8(LoopModes)], 'uint8');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting loop mode. Confirm code not returned.');
                end
            end
            obj.LoopMode = LoopModes; 
        end
        function set.LoopDuration(obj, Duration)
            if obj.Initialized
                if length(Duration) ~= obj.maxWaves
                    error('Error setting loop durations - a duration must exist for each wave.')
                end
                obj.Port.write('-', 'uint8', Duration*obj.SamplingRate, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting loop duration. Confirm code not returned.');
                end
            end
            obj.LoopDuration = Duration;
        end
        function set.SamplingRate(obj, sf)
            if obj.Initialized
                if sf > obj.maxSamplingRate || sf < 1
                    error(['Error setting sampling rate: valid rates are in range: [1 ' num2str(obj.maxSamplingRate) '] Hz'])
                end
                SamplingPeriodMicroseconds = (1/sf)*1000000;
                obj.Port.write(['S' typecast(single(SamplingPeriodMicroseconds), 'uint8')], 'uint8');
                if sum(obj.LoopMode) > 0 % Re-compute loop durations (in units of samples)
                    obj.Port.write('-', 'uint8', obj.LoopDuration*sf, 'uint32'); % Update loop durations
                    Confirmed = obj.Port.read(1, 'uint8');
                end
            end
            obj.SamplingRate = sf;
        end
        function set.AMenvelope(obj, Envelope)
            if isempty(Envelope)
                obj.Port.write(['E' 0], 'uint8');
                Confirmed = obj.Port.read(1, 'uint8');
            else
                nSamples = length(Envelope);
                if nSamples > obj.maxEnvelopeSamples
                    error(['Error: The AM envelope can have at most ' num2str(obj.maxEnvelopeSamples) ' samples.'])
                end
                if (sum(Envelope > 1) > 0) || (sum (Envelope < 0) > 0)
                    error('Error: all samples in the envelope must be between 0 and 1.')
                end
                obj.Port.write(['E' 1 'M'], 'uint8', nSamples, 'uint16', typecast(single(Envelope), 'uint8'), 'uint8');
                Confirmed = obj.Port.read(2, 'uint8');
            end
             obj.AMenvelope = Envelope;
        end
        function loadSound(obj, SoundIndex, Waveform, varargin) % Optional argument: LoopMode (0 = off, 1 = on)
            if SoundIndex > obj.maxWaves
                error(['Error: cannot load sound# ' num2str(SoundIndex) '; only ' num2str(obj.maxWaves) ' sounds are supported.'])
            end
            [nChannels, nSamples] = size(Waveform);
            if nChannels == 1
                isStereo = 0;
            elseif nChannels == 2
                isStereo = 1;
            else
                error('Error: waveform must be a 1xn (mono) or 2xn (stereo) vector');
            end
            CurrentLoopMode = obj.LoopMode(SoundIndex);
            if nargin == 4
                NewLoopMode = varargin{1};
                if NewLoopMode ~= CurrentLoopMode
                    obj.LoopMode(SoundIndex) = NewLoopMode;
                end
            end
            minWave = min(min(Waveform));
            maxWave = max(max(Waveform));
            if (minWave < obj.OutputRange(1)) || (maxWave > obj.OutputRange(2))
                error(['Error setting waveform: All voltages must be within the current range: ' obj.OutputRange '.'])
            end
            VoltageWidth = (obj.OutputRange(2) - obj.OutputRange(1));
            Offset = VoltageWidth/2;
            WaveBits = ceil(((Waveform+Offset)/VoltageWidth)*65535);
            obj.Port.write([obj.LoadOp SoundIndex-1 isStereo], 'uint8', nSamples, 'uint32', WaveBits(1:end), 'uint16');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error: Load not confirmed.')
            end
            obj.Waveforms{SoundIndex} = Waveform;
            obj.WaveformsLoaded(SoundIndex) = 1;
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
        function push(obj)
            obj.Port.write('*', 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error pushing loaded sounds. Confirm code not returned.');
            end
        end
        function play(obj, waveIndex) % Play a waveform immediately on specified channel(s)
            if waveIndex <= obj.maxWaves
                obj.Port.write(['P' waveIndex-1], 'uint8');   
            else
                error(['Error: cannot play sound# ' num2str(waveIndex) '; only ' num2str(obj.maxWaves) ' sounds are supported.'])
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