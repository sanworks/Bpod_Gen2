classdef BpodHiFi < handle
    properties
        Port
        LoadMode % 'Fast' to load sounds fast (potentially disrupting playback) or 'Safe' to load slower, but playback-safe
        AMenvelope % If defined, a vector of amplitude coefficients for each waveform on onest + offset (in reverse)
        LoopMode %For each wave, 'On' loops the waveform until LoopDuration seconds, or until toggled off. 'Off' = one shot.
        LoopDuration % (seconds) In loop mode, specifies the duration to loop the waveform following a trigger. 0 = until canceled.
    end
    properties (Access = private)
        maxWaves = 20;
        maxEnvelopeSamples = 2000;
        waveforms;
        LoadOp = 'L';
        SamplingRate = 192000;
        Initialized = 0;
    end
    methods
        function obj = BpodHiFi(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
            obj.Port.write(243, 'uint8');
            Ack = obj.Port.read(1, 'uint8');
            if Ack ~= 244
                error('Error: Incorrect handshake byte returned');
            end
            obj.LoadMode = 'Fast';
            waveforms = cell(1,obj.maxWaves);
            obj.LoopMode = logical(zeros(1,obj.maxWaves));
            obj.LoopDuration = zeros(1,obj.maxWaves);
            obj.Initialized = 1;
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
        function set.LoopDuration(obj, Duration)
            if length(Duration) ~= obj.maxWaves
                error('Error setting loop durations - a duration must exist for each wave.')
            end
            obj.Port.write('-', 'uint8', Duration*obj.SamplingRate, 'uint32');
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error setting loop duration. Confirm code not returned.');
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
        function load(obj, waveIndex, waveform) % Must be stereo 2xn vector
            if (waveIndex < 1) || (waveIndex > obj.maxWaves)
                error(['Error: waveIndex must be in range 1: ' num2str(obj.maxWaves)])
            end
            [nChannels,nSamples] = size(waveform);
            
            switch nChannels
                case 1
                    waveform = [waveform; waveform]; % Convert to Stereo
                case 2
                    
                otherwise
                    error('Error: Audio data must be a 1xn (Mono) or 2xn (Stereo) array of sound samples')
            end
            formattedWaveform = waveform(1:end)*32767;
            % The single line transmission writes too fast, causing dropped data
            %obj.Port.write([obj.LoadOp waveIndex-1], 'uint8', nSamples, 'uint32', formattedWaveform, 'int16');
            
            % Breaking the transmission into packets fixes the issue
            PacketSize = 200;
            nFullPackets = length(formattedWaveform)/PacketSize;
            Pos = 1;
            partialPacketLength = rem(length(formattedWaveform), PacketSize);
            obj.Port.write(['L' waveIndex-1], 'uint8', nSamples, 'uint32');
            for i = 1:nFullPackets
                obj.Port.write(formattedWaveform(Pos:Pos+PacketSize-1), 'int16');
                Pos = Pos + PacketSize;
            end
            if partialPacketLength > 0
                obj.Port.write(formattedWaveform(Pos:end), 'int16');
            end
            
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error loading waveform. Confirm code not returned.');
            end
            obj.waveforms{waveIndex} = int16(formattedWaveform*32767);
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
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end