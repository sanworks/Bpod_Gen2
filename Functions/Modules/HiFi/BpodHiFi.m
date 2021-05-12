classdef BpodHiFi < handle
    properties
        Port
        SamplingRate
        LoadMode % 'Fast' to load sounds fast (potentially disrupting playback) or 'Safe' to load slower, but playback-safe
        AMenvelope % If defined, a vector of amplitude coefficients for each waveform on onest + offset (in reverse)
        LoopMode %For each wave, 'On' loops the waveform until LoopDuration seconds, or until toggled off. 'Off' = one shot.
        LoopDuration % (seconds) In loop mode, specifies the duration to loop the waveform following a trigger. 0 = until canceled.
        HeadphoneAmpEnabled
        HeadphoneAmpGain
        SynthAmplitude
        SynthFrequency
        SynthWaveform
        SynthAmplitudeFade % nSamples to reach setpoint (instant if set to 0)
        DigitalAttenuation_dB
    end
    properties (Access = private)
        maxWaves = 20;
        maxSamplesPerWaveform = 0;
        maxEnvelopeSamples = 2000;
        MaxAmplitudeBits = 32767;
        MaxSynthFrequency = 80000;
        MaxAmplitudeFadeSamples = 1920000;
        validSynthWaveforms = {'WhiteNoise', 'Sine'};
        LoadOp = '>';
        Initialized = 0;
        bitDepth
        audioDataType
        isHD
        minAttenuation_Pro = -103;
        minAttenuation_HD = -120;
        headphoneAmpEnableWarned = false;
        headphoneAmpGainWarned = false;
        MaxDataTransferAttempts = 5;
    end
    methods
        function obj = BpodHiFi(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200, 'Java');
            obj.Port.write(243, 'uint8');
            Ack = obj.Port.read(1, 'uint8');
            if Ack ~= 244
                error('Error: Incorrect handshake byte returned');
            end
            if ~ispc && ~obj.Port.UsePsychToolbox == 1
                warning('HiFi Module data transfer may be unstable unless PsychToolbox is installed. Please install PsychToolbox for optimal performance.');
            end
            obj.Port.write('I', 'uint8');
            InfoParams8Bit = obj.Port.read(4, 'uint8');
            InfoParams32Bit = obj.Port.read(3, 'uint32');
            obj.SamplingRate = double(InfoParams32Bit(1));
            obj.isHD = InfoParams8Bit(1);
            obj.bitDepth = InfoParams8Bit(2);
            obj.maxWaves = InfoParams8Bit(3);
            digitalAttBits = InfoParams8Bit(4);
            obj.DigitalAttenuation_dB = double(digitalAttBits)*-0.5;
            obj.maxSamplesPerWaveform = InfoParams32Bit(2)*obj.SamplingRate;
            obj.maxEnvelopeSamples = InfoParams32Bit(3);
            obj.LoadMode = 'Safe';
            obj.HeadphoneAmpEnabled = false;
            obj.HeadphoneAmpGain = 52;
            obj.SynthAmplitude = 0;
            obj.SynthFrequency = 1000;
            obj.SynthWaveform = 'WhiteNoise';
            obj.SynthAmplitudeFade = 0;
            obj.LoopMode = logical(zeros(1,obj.maxWaves));
            obj.LoopDuration = zeros(1,obj.maxWaves);
            switch obj.bitDepth
                case 16
                    obj.audioDataType = 'int16';
                case 32
                    obj.audioDataType = 'int32';
            end
            obj.Initialized = 1;
            try
                % Load 10s of blank audio data. This will force Windows to configure USB serial interface for high speed transfer.
                obj.Port.write([obj.LoadOp 0], 'uint8', obj.SamplingRate*10, 'uint32', zeros(1,20*obj.SamplingRate), 'int16');
                Confirmed = obj.Port.read(1, 'uint8');
            catch
            end
        end
        function set.SamplingRate(obj, SF)
            if obj.Initialized == 1
                switch SF
                    case 44100
                    case 48000
                    case 96000
                    case 192000
                    otherwise
                        error('Error: Invalid sampling rate.');
                end
                obj.Port.write('S', 'uint8', SF, 'uint32');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting sampling rate. Confirm code not returned.');
                end
            end
            obj.SamplingRate = double(SF);
        end
        function set.DigitalAttenuation_dB(obj, attenuation)
            if obj.Initialized == 1
                if obj.isHD
                    minimumAttenuation = obj.minAttenuation_HD;
                else
                    minimumAttenuation = obj.minAttenuation_Pro;
                end
                if (attenuation > 0) || (attenuation < minimumAttenuation)
                    error(['Error: digital attenuation must fall between 0 and ' num2str(minimumAttenuation) ' dB']);
                end
                attenuationBits = attenuation*-2;
                obj.Port.write(['A' attenuationBits], 'uint8');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting digital attenuation. Confirm code not returned.');
                end
            end
            obj.DigitalAttenuation_dB = attenuation;
        end
        function set.LoadMode(obj,Mode)
            switch Mode
                case 'Fast'
                    obj.LoadOp = 'L';
                case 'Safe'
                    obj.LoadOp = '>';
                otherwise
                    error(['Error: ' Mode ' is not a valid load mode. Valid modes are: ''Fast'', ''Safe'''])
            end
            obj.LoadMode = Mode;
        end
        function set.SynthAmplitude(obj, Amplitude)
            if (Amplitude < 0) || (Amplitude > 1)
                error(['Error: Synth amplitude must fall in range 0-1 where 0 is no signal, and 1 is max range'])
            end
            AmplitudeBits = round(Amplitude*obj.MaxAmplitudeBits);
            obj.Port.write('N', 'uint8', AmplitudeBits, 'uint16');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting synth amplitude. Confirm code not returned.');
            end
            obj.SynthAmplitude = AmplitudeBits;
        end
        function set.SynthFrequency(obj, NewFrequency)
            if (NewFrequency < 0) || (NewFrequency > obj.MaxSynthFrequency)
                error(['Error: Synth frequency must fall in range 0-' num2str(obj.MaxSynthFrequency)])
            end
            obj.Port.write('F', 'uint8', NewFrequency*1000, 'uint32');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting synth frequency. Confirm code not returned.');
            end
            obj.SynthFrequency = NewFrequency;
        end
        function set.SynthWaveform(obj, NewWaveform)
            thisWaveform = find(strcmp(NewWaveform, obj.validSynthWaveforms));
            if isempty(thisWaveform)
                error(['Error: Invalid Waveform name. Valid waveforms are: WhiteNoise, Sine'])
            end
            obj.Port.write(['W' thisWaveform-1], 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting synth waveform. Confirm code not returned.');
            end
            obj.SynthWaveform = NewWaveform;
        end
        function set.SynthAmplitudeFade(obj, nSamples)
            if (nSamples < 0) || (nSamples > obj.MaxAmplitudeFadeSamples)
                error(['Error: Amplitude fade must fall in range 0-' num2str(obj.MaxAmplitudeFadeSamples) ' samples.'])
            end
            obj.Port.write('Z', 'uint8', nSamples, 'uint32');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting amplitude fade. Confirm code not returned.');
            end
            obj.SynthAmplitudeFade = nSamples;
        end
        function set.LoopMode(obj, LoopModes)
            if length(LoopModes) ~= obj.maxWaves
                error('Error setting loop modes - one loop mode must exist for each wave.')
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
            obj.LoopMode = LoopModes; 
        end
        function set.HeadphoneAmpEnabled(obj,State)
            State = logical(State);
            if ~obj.isHD
                obj.Port.write(['H' uint8(State)], 'uint8');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error enabling headphone amp. Confirm code not returned.');
                end
            else
                if ~obj.headphoneAmpEnableWarned && obj.Initialized == 1
                    disp('Warning: HeadphoneAmpEnabled setting ignored. The HD version of the HiFi Module does not have a headphone amplifier.');
                    obj.headphoneAmpEnableWarned = true;
                end
            end
            obj.HeadphoneAmpEnabled = State;
        end
        function set.HeadphoneAmpGain(obj,Gain)
            Gain = uint8(Gain);
            if Gain > 63 || Gain < 0
                 error('Error: Gain must be in range 0-63.');
            end
            if ~obj.isHD
                obj.Port.write(['G' Gain], 'uint8');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed ~= 1
                    error('Error setting headphone amp gain. Confirm code not returned.');
                end
            else
                if ~obj.headphoneAmpGainWarned && obj.Initialized == 1
                    disp('Warning: HeadphoneAmpGain setting ignored. The HD version of the HiFi Module does not have a headphone amplifier.');
                    obj.headphoneAmpGainWarned = true;
                end
            end
            obj.HeadphoneAmpGain = Gain;
        end
        function set.LoopDuration(obj, Duration)
            if obj.Initialized == 1
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
        function load(obj, waveIndex, waveform, varargin) % Must be stereo 2xn vector
            PacketSize = 0;
            if nargin > 3
                PacketSize = varargin{1};
            end
            if (waveIndex < 1) || (waveIndex > obj.maxWaves)
                error(['Error: wave index must be in range [1, ' num2str(obj.maxWaves) ']'])
            end
            [nChannels,nSamples] = size(waveform);
            
            switch nChannels
                case 1
                    waveform = [waveform; waveform]; % Convert to Stereo
                case 2
                    
                otherwise
                    error('Error: Audio data must be a 1xn (Mono) or 2xn (Stereo) array of sound samples')
            end
            if length(waveform) > obj.maxSamplesPerWaveform
                error(['Error: Waveform too long. The current firmware supports up to ' num2str(obj.maxSamplesPerWaveform) ' samples per waveform.']);
            end
            if obj.bitDepth == 16
                formattedWaveform = waveform(1:end)*32767;
            elseif obj.bitDepth == 32
                formattedWaveform = waveform(1:end)*2147483647;
            end
            nTries = 0;
            while nTries < obj.MaxDataTransferAttempts
                obj.Port.write([obj.LoadOp waveIndex-1], 'uint8', nSamples, 'uint32', formattedWaveform, 'int16');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed == 1
                    break;
                elseif Confirmed == 0
                    disp(['HiFi Module: Data was dropped during USB transfer. Retries attempted = ' num2str(nTries)])
                    nTries = nTries + 1;
                else
                    error('Error loading waveform. Confirm code not returned.');
                end
            end
            if nTries > 0
                disp('HiFi Module: Transfer retry success');
            end
        end
        function play(obj, waveIndex) % Play a waveform immediately on specified channel(s)
            if waveIndex <= obj.maxWaves
                obj.Port.write(['P' waveIndex-1], 'uint8');
            else
                error(['Error: cannot play sound# ' num2str(waveIndex) '; only ' num2str(obj.maxWaves) ' sounds are supported.'])
            end
        end
        function push(obj)
            obj.Port.write('*', 'uint8');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error pushing loaded sounds. Confirm code not returned.');
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