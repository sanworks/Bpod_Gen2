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

% BpodHiFi is a class to interface with the Bpod HiFi Module
% via its USB connection to the PC.
%
% User-configurable device parameters are exposed as class properties. Setting
% the value of a property will trigger its 'set' method to update the device.
%
% Docs:
% https://sanworks.github.io/Bpod_Wiki/module-documentation/hifi-module/
% Documentation of properties and methods is given in-line below.
%
% Example usage:
%
% H = BpodHiFi('COM3'); % Create an instance of BpodHiFi,
%                         connecting to the Bpod HiFi Module on port COM3
% H.SamplingRate = 96000; % Set the sampling rate to 96kHz
% myWaveform = GenerateSineWave(96000, 1000, 1); % Generate a 1-second 1kHz pure tone
% H.load(2, myWaveform); % Load myWaveform to the HiFi module at position 2
% H.push; % Add all newly loaded waveforms to the current sound set,
%           overwriting any waveforms at the same position(s)
% H.play(2); % Play waveform 2
% clear H; % clear the object from the workspace, releasing the USB serial port

classdef BpodHiFi < handle
    properties
        Port % ArCOM wrapper to simplify data transactions on the USB serial port
        Info % Contains useful info about the specific hardware detected
        SamplingRate % Audio playback sampling rate. Valid rates are: 44.1kHz, 48kHz, 96kHz, 192kHz
        AMenvelope % If defined, a vector of amplitude coefficients for each waveform on onest + offset (in reverse)
        HeadphoneAmpEnabled % Headphone amp control on HiFi SD model. 0 = disabled, 1 = enabled.
        HeadphoneAmpGain % Headphone amp gain on HiFi SD model. Ignored on HiFi HD
        SynthAmplitude % Amplitude of synth waveform (default = 0, range = 0, 1)
        SynthFrequency % Frequency of synth waveform (default = 1000, range = 20, 80000)
        SynthWaveform % Synth waveform (default = 'WhiteNoise', alternative = 'Sine')
        SynthAmplitudeFade % nSamples to reach synth amplitude setpoint (instant if set to 0)
        DigitalAttenuation_dB % attenuation of full-scale output signal (i.e. digital volume control)
        VerboseMode = false; % Set to true to view data transfer info at the MATLAB command window
    end

    properties (Access = private)
        maxWaves % Maximum number of waveforms that can be stored on the device
        maxSamplesPerWaveform % Maximum number of samples per waveform stored on the device
        maxEnvelopeSamples % Maximum number of AM envelope samples stored on the device 
        maxAmplitudeBits = 65535; % Maximum bit value for the output signal
        maxSynthFrequency = 80000; % Maximum frequency of synth waveform
        maxAmplitudeFadeSamples = 1920000; % Maximum number of samples for synth amplitude fade
        validSynthWaveforms = {'WhiteNoise', 'Sine'}; % Synth waveform names
        initialized = false; % Flag indicating whether the constructor has finished running
        bitDepth % Bit depth of audio ADC
        audioDataType % Data type of audio data (uint16 or uint32)
        isHD % Flag indicating whether the connected HiFi module is HD or SD
        minAttenuation_SD = -103; % Minimum DigitalAttenuation_dB for HiFi SD
        minAttenuation_HD = -120; % Minimum DigitalAttenuation_dB for HiFi HD
        headphoneAmpEnableWarned = false; % Flag indicating that headphone amp enable warning was sent
        headphoneAmpGainWarned = false; % Flag indicating that headphone amp gain warning was sent
        maxDataTransferAttempts = 5; % Maximum number of times to retry dropped data transfer
    end
    methods
        function obj = BpodHiFi(portString, varargin)
            % Constructor
            portType = 0; 
            if nargin > 1
                portString = varargin{1};
                if strcmp(portString, 'Java')
                    portType = 1;
                end
            end
            if portType == 0
                obj.Port = ArCOMObject_Bpod(portString, [], [], [], 1000000, 1000000);
            elseif portType == 1
                obj.Port = ArCOMObject_Bpod(portString, [], 'Java', [], 1000000, 1000000);
            end
            obj.Port.write(243, 'uint8');
            ack = obj.Port.read(1, 'uint8');
            if ack ~= 244
                error('Error: Incorrect handshake byte returned');
            end
            if ~ispc && ~obj.Port.UsePsychToolbox == 1 && verLessThan('matlab', '9.7')
                warning(['HiFi Module data transfer may be unstable unless PsychToolbox is installed. ' ...
                         'Please install PsychToolbox for optimal performance.']);
            end
            obj.Port.write('I', 'uint8');
            infoParams8Bit = obj.Port.read(4, 'uint8');
            infoParams32Bit = obj.Port.read(3, 'uint32');
            obj.SamplingRate = double(infoParams32Bit(1));
            obj.isHD = infoParams8Bit(1);
            obj.bitDepth = infoParams8Bit(2);
            obj.maxWaves = infoParams8Bit(3);
            digitalAttBits = infoParams8Bit(4);
            obj.DigitalAttenuation_dB = double(digitalAttBits)*-0.5;
            obj.maxSamplesPerWaveform = infoParams32Bit(2)*192000;
            obj.maxEnvelopeSamples = infoParams32Bit(3);
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
            obj.Info.maxAmplitudeFadeSamples = obj.maxAmplitudeFadeSamples;
            switch obj.bitDepth
                case 16
                    obj.audioDataType = 'int16';
                case 32
                    obj.audioDataType = 'int32';
            end
            obj.initialized = 1;
            % Load 10s of blank audio data. This will force Windows to configure USB serial interface for high speed transfer.
            obj.load(1, zeros(2,10*obj.SamplingRate));
        end

        function set.SamplingRate(obj, sf)
            % Set the audio playback sampling rate
            % Arguments: sf, the sampling frequency (Hz)
            if obj.initialized == 1
                switch sf
                    case 44100
                    case 48000
                    case 96000
                    case 192000
                    otherwise
                        error('Error: Invalid sampling rate.');
                end
                obj.Port.write('S', 'uint8', sf, 'uint32');
                obj.confirmTransmission('setting sampling rate');
            end
            obj.SamplingRate = double(sf);
        end

        function set.DigitalAttenuation_dB(obj, attenuation)
            % Set digital attenuation (digital volume control)
            % Note that for best audio quality, when possible set DigitalAttenuation_dB to 0 
            % and attenuate with the analog volume control on a high quality audio amplifier.
            % Arguments: attenuation, the amount to attenuate the full-scale signal (dB FS)
            if obj.initialized == 1
                if obj.isHD
                    minimumAttenuation = obj.minAttenuation_HD;
                else
                    minimumAttenuation = obj.minAttenuation_SD;
                end
                if (attenuation > 0) || (attenuation < minimumAttenuation)
                    error(['Error: digital attenuation must fall between 0 and ' num2str(minimumAttenuation) ' dB']);
                end
                attenuationBits = attenuation*-2;
                obj.Port.write(['A' attenuationBits], 'uint8');
                obj.confirmTransmission('setting digital attenuation');
            end
            obj.DigitalAttenuation_dB = attenuation;
        end

        function set.SynthAmplitude(obj, amplitude)
            % Set amplitude of the synth waveform. 
            % Arguments: amplitude, the fraction of full-scale waveform amplitude. Range = 0, 1
            if (amplitude < 0) || (amplitude > 1)
                error('Error: Synth amplitude must fall in range 0-1 where 0 is no signal, and 1 is max range')
            end
            amplitudeBits = round(amplitude*obj.maxAmplitudeBits);
            obj.Port.write('N', 'uint8', amplitudeBits, 'uint16');
            obj.confirmTransmission('setting synth amplitude');
            obj.SynthAmplitude = amplitudeBits;
        end

        function set.SynthFrequency(obj, newFrequency)
            % Set the frequency of the synth waveform.
            % Arguments: newFrequency (Hz)
            if (newFrequency < 0) || (newFrequency > obj.maxSynthFrequency)
                error(['Error: Synth frequency must fall in range 0-' num2str(obj.maxSynthFrequency)])
            end
            obj.Port.write('F', 'uint8', newFrequency*1000, 'uint32');
            obj.confirmTransmission('setting synth frequency');
            obj.SynthFrequency = newFrequency;
        end

        function set.SynthWaveform(obj, newWaveform)
            % Set the synth waveform
            % Arguments: newWaveform (char array). Can be 'WhiteNoise' or 'Sine'
            thisWaveform = find(strcmp(newWaveform, obj.validSynthWaveforms));
            if isempty(thisWaveform)
                error(['Error: Invalid Waveform name. Valid waveforms are: WhiteNoise, Sine'])
            end
            obj.Port.write(['W' thisWaveform-1], 'uint8');
            obj.confirmTransmission('setting synth waveform');
            obj.SynthWaveform = newWaveform;
        end

        function set.SynthAmplitudeFade(obj, nSamples)
            % Set the duration of synth amplitude fade. When synth
            % amplitude is set, it will fade from the current setting to
            % the new setting over the course of a period of samples set by nSamples
            if (nSamples < 0) || (nSamples > obj.maxAmplitudeFadeSamples)
                error(['Error: Amplitude fade must fall in range 0-' num2str(obj.maxAmplitudeFadeSamples) ' samples.'])
            end
            obj.Port.write('Z', 'uint8', nSamples, 'uint32');
            obj.confirmTransmission('setting amplitude fade duration');
            obj.SynthAmplitudeFade = nSamples;
        end

        function set.HeadphoneAmpEnabled(obj,state)
            % Enable or disable the headphone amplifier on HiFi SD. Note
            % that the HD model does not have a headphone amplifier, and
            % this parameter is ignored.
            % Arguments: state (0 = disabled, 1 = enabled)
            state = logical(state);
            if ~obj.isHD
                obj.Port.write(['H' uint8(state)], 'uint8');
                obj.confirmTransmission('enabling headphone amp');
            else
                if ~obj.headphoneAmpEnableWarned && obj.initialized == 1
                    if obj.VerboseMode
                        disp(['HiFi Module: HeadphoneAmpEnabled setting ignored. ' ...
                              'The HD version of the HiFi Module does not have a headphone amplifier.']);
                        obj.headphoneAmpEnableWarned = true;
                    end
                end
            end
            obj.HeadphoneAmpEnabled = state;
        end

        function set.HeadphoneAmpGain(obj,gain)
            % Set the gain of the HiFi SD headphone amplifier. 
            % Parameters: gain (range = 0, 63)
            gain = uint8(gain);
            if gain > 63 || gain < 0
                 error('Error: Gain must be in range 0-63.');
            end
            if ~obj.isHD
                obj.Port.write(['G' gain], 'uint8');
                obj.confirmTransmission('setting headphone amp gain');
            else
                if ~obj.headphoneAmpGainWarned && obj.initialized == 1
                    if obj.VerboseMode
                        disp(['HiFi Module: HeadphoneAmpGain setting ignored. ' ...
                              'The HD version of the HiFi Module does not have a headphone amplifier.']);
                        obj.headphoneAmpGainWarned = true;
                    end
                end
            end
            obj.HeadphoneAmpGain = gain;
        end

        function set.AMenvelope(obj, envelope)
            % Set an AM envelope. The HiFi module will multiple the audio
            % waveform by the coefficient at each sample in the envelope at
            % sound onset, and in reverse at sound offset. This can
            % mitigate speaker "pop" and create fade-in and fade-out effects.
            % Note: Setting an empty envelope will disable the envelope feature.
            % Parameters: envelope, a 1xn array of doubles, in range 0, 1
            if isempty(envelope)
                obj.Port.write(['E' 0], 'uint8');
                obj.confirmTransmission('setting AM envelope');
            else
                nSamples = length(envelope);
                if nSamples > obj.maxEnvelopeSamples
                    error(['Error: The AM envelope can have at most ' num2str(obj.maxEnvelopeSamples) ' samples.'])
                end
                if (sum(envelope > 1) > 0) || (sum (envelope < 0) > 0)
                    error('Error: all samples in the envelope must be between 0 and 1.')
                end
                obj.Port.write(['E' 1 'M'], 'uint8', nSamples, 'uint16', typecast(single(envelope), 'uint8'), 'uint8');
                obj.confirmTransmission('setting AM envelope');
                obj.confirmTransmission('setting AM envelope');
            end
             obj.AMenvelope = envelope;
        end

        function load(obj, waveIndex, waveform, varargin)
            % Loads an audio waveform to the HiFi module's internal memory at a target position.
            % Arguments:
            % waveIndex: The position of the sound (range = 1, 20)
            % waveform: The audio data. This is a 1xnSamples or 2xnSamples array with samples in range -1, 1.
            %
            % Optional arguments: (...'LoopMode', lm, 'LoopDuration', ld)
            % lm = 0 (off) or 1 (on)
            % ld = Loop Duration in seconds (total time to play looped sound before stopping)
            % Arguments must be given in this order and with argument/value pairs as shown above for efficient processing
            if obj.VerboseMode
                startTime = now;
            end
            loopMode = 0;
            loopDuration = 0;
            if nargin > 4 
                loopMode = varargin{2};
            end
            if nargin > 6 
                loopDuration = varargin{4}*obj.SamplingRate;
            end
            if (waveIndex < 1) || (waveIndex > obj.maxWaves)
                error(['Error: wave index must be in range [1, ' num2str(obj.maxWaves) ']'])
            end
            if (loopDuration < 0)
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
                error(['Error: Waveform too long. The current firmware supports up to '... 
                       num2str(obj.maxSamplesPerWaveform) ' samples per waveform.']);
            end
            if obj.VerboseMode
                waveType = 'Mono';
                if isStereo
                   waveType = 'Stereo'; 
                end
                disp(['HiFi Module: Loading a ' num2str(nSamples) ' sample ' waveType ' waveform to slot#' num2str(waveIndex) '.']); 
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
            byteString = [uint8(['L' waveIndex-1 isStereo loopMode]) typecast(uint32([loopDuration nSamples]), 'uint8')...
                          typecast(int16(formattedWaveform), 'uint8')];
            while nTries < obj.maxDataTransferAttempts
                obj.Port.write(byteString, 'uint8');
                confirmed = obj.Port.read(1, 'uint8');
                if confirmed == 1
                    break;
                elseif confirmed == 0
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
                disp(['HiFi Module: Transfer complete. Transfer time: ' num2str(transferTime)... 
                      's. Transfer speed: ' num2str(transferSpeed) ' Mb/s']); 
            end
        end

        function play(obj, waveIndex)
            % Play an audio waveform immediately
            % Arguments: waveIndex, the sound to play
            if waveIndex <= obj.maxWaves
                obj.Port.write(['P' waveIndex-1], 'uint8');
            else
                error(['Error: cannot play sound# ' num2str(waveIndex) '; only ' num2str(obj.maxWaves) ' sounds are supported.'])
            end
        end

        function push(obj)
            % Add any newly loaded sounds to the active sound set, overwriting existing sound(s) at the target positions.
            obj.Port.write('*', 'uint8');
            obj.confirmTransmission('pushing loaded sounds');
        end

        function stop(obj)
            % Stop ongoing sound playback. This command is ignored if playback is already stopped.
            obj.Port.write('X', 'uint8');
        end

        function result = testPSRAM(obj)
            % Test the module's 8MB PSRAM IC. As of firmware v5 the PSRAM IC is
            % not used. It is installed for future features, or custom user firmware.
            obj.Port.write('T', 'uint8');
            
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

        function scanDuringUSBTransfer(obj, state)
            % Enable or disable scanning the state machine for commands during USB transfer
            % Parameters: state = 0 (do not scan), 1 (scan)
            if ~(state == 1 || state == 0)
                error('State machine scan during USB transfer must be equal to 1 (enabled) or 0 (disabled)')
            end
            obj.Port.write(['&' state], 'uint8');
            obj.confirmTransmission('setting state of scan during USB transfer');
        end

        function delete(obj)
            % Destructor
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