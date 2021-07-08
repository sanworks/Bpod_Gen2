classdef BpodHiFi < handle
    properties
        Port
        Info
        SamplingRate
        AMenvelope % If defined, a vector of amplitude coefficients for each waveform on onest + offset (in reverse)
        HeadphoneAmpEnabled
        HeadphoneAmpGain
        SynthAmplitude
        SynthFrequency
        SynthWaveform
        SynthAmplitudeFade % nSamples to reach setpoint (instant if set to 0)
        DigitalAttenuation_dB
        VerboseMode = false;
    end
    properties (Access = private)
        maxWaves = 20;
        maxSamplesPerWaveform = 0;
        maxEnvelopeSamples = 2000;
        MaxAmplitudeBits = 32767;
        MaxSynthFrequency = 80000;
        MaxAmplitudeFadeSamples = 1920000;
        validSynthWaveforms = {'WhiteNoise', 'Sine'};
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
            obj.Port = ArCOMObject_Bpod(portString, 115200);
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
            obj.maxSamplesPerWaveform = InfoParams32Bit(2)*192000;
            obj.maxEnvelopeSamples = InfoParams32Bit(3);
            obj.HeadphoneAmpEnabled = false;
            obj.HeadphoneAmpGain = 52;
            obj.SynthAmplitude = 0;
            obj.SynthFrequency = 1000;
            obj.SynthWaveform = 'WhiteNoise';
            obj.SynthAmplitudeFade = 0;
            obj.AMenvelope = [];
            obj.Info = struct;
            obj.Info.isHD = obj.isHD;
            obj.Info.bitDepth = obj.bitDepth;
            obj.Info.maxSounds = obj.maxWaves;
            obj.Info.maxSamplesPerWaveform = obj.maxSamplesPerWaveform;
            obj.Info.maxEnvelopeSamples = obj.maxEnvelopeSamples;
            obj.Info.maxAmplitudeFadeSamples = obj.MaxAmplitudeFadeSamples;
            switch obj.bitDepth
                case 16
                    obj.audioDataType = 'int16';
                case 32
                    obj.audioDataType = 'int32';
            end
            obj.Initialized = 1;
            % Load 10s of blank audio data. This will force Windows to configure USB serial interface for high speed transfer.
            obj.load(1, zeros(2,10*obj.SamplingRate));
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
                    if obj.VerboseMode
                        disp('HiFi Module: HeadphoneAmpEnabled setting ignored. The HD version of the HiFi Module does not have a headphone amplifier.');
                        obj.headphoneAmpEnableWarned = true;
                    end
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
                    if obj.VerboseMode
                        disp('HiFi Module: HeadphoneAmpGain setting ignored. The HD version of the HiFi Module does not have a headphone amplifier.');
                        obj.headphoneAmpGainWarned = true;
                    end
                end
            end
            obj.HeadphoneAmpGain = Gain;
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
            % Optional arguments: (...'LoopMode', LM, 'LoopDuration', LD)
            % Where LM = 0 (off) or 1 (on) and LD = Loop Duration in seconds (total time to play looped sound before stopping)
            % Arguments must be given in this order and with argument/value pairs as shown above for efficient processing
            if obj.VerboseMode
                startTime = now;
            end
            LoopMode = 0;
            LoopDuration = 0;
            if nargin > 4 
                LoopMode = varargin{2};
            end
            if nargin > 6 
                LoopDuration = varargin{4}*obj.SamplingRate;
            end
            if (waveIndex < 1) || (waveIndex > obj.maxWaves)
                error(['Error: wave index must be in range [1, ' num2str(obj.maxWaves) ']'])
            end
            if (LoopDuration < 0)
                error('Error: loop duration must be 0 or a positive value in seconds')
            end
            [nChannels,nSamples] = size(waveform);
            switch nChannels
                case 1
                    isStereo = 0;
                case 2
                    isStereo = 1;
                otherwise
                    error('Error: Audio data must be a 1xn (Mono) or 2xn (Stereo) array of sound samples')
            end
            if length(waveform) > obj.maxSamplesPerWaveform
                error(['Error: Waveform too long. The current firmware supports up to ' num2str(obj.maxSamplesPerWaveform) ' samples per waveform.']);
            end
            if obj.VerboseMode
                WaveType = 'Mono';
                if isStereo
                   WaveType = 'Stereo'; 
                end
                disp(['HiFi Module: Loading a ' num2str(nSamples) ' sample ' WaveType ' waveform to slot#' num2str(waveIndex) '.']); 
            end
            if obj.bitDepth == 16
                formattedWaveform = waveform(1:end)*32767;
            elseif obj.bitDepth == 32
                formattedWaveform = waveform(1:end)*2147483647;
            end
            if nSamples == 1 
                if isStereo == 1
                    formattedWaveform = formattedWaveform';
                end
            end
            nTries = 0;
            byteString = [uint8(['L' waveIndex-1 isStereo LoopMode]) typecast(uint32([LoopDuration nSamples]), 'uint8')...
                          typecast(int16(formattedWaveform), 'uint8')];
            while nTries < obj.MaxDataTransferAttempts
                obj.Port.write(byteString, 'uint8');
                Confirmed = obj.Port.read(1, 'uint8');
                if Confirmed == 1
                    break;
                elseif Confirmed == 0
                    if obj.VerboseMode
                        disp(['HiFi Module: Data was dropped during USB transfer. Retries attempted = ' num2str(nTries)])
                    end
                    nTries = nTries + 1;
                else
                    error('Error loading waveform. Confirm code not returned.');
                end
            end
            if nTries > 0
                if obj.VerboseMode
                    disp('HiFi Module: Transfer retry success');
                end
            end
            if obj.VerboseMode
                transferTime = (now - startTime)*100000;
                transferSpeed = ((length(byteString) / transferTime)/1000000)*8;
                disp(['HiFi Module: Transfer complete. Transfer time: ' num2str(transferTime) 's. Transfer speed: ' num2str(transferSpeed) ' Mb/s']); 
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
        function result = testPSRAM(obj)
            obj.Port.write('T', 'uint8');
            memSize = obj.Port.read(1, 'uint8');
            disp(['Testing PSRAM. ' num2str(memSize) ' MB detected. This may take up to 20 seconds.']);
            while obj.Port.bytesAvailable == 0
                pause(.1);
            end
            result = obj.Port.read(1, 'uint8');
            if result
                disp('Test PASSED');
            else
                disp('Test FAILED');
            end
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end