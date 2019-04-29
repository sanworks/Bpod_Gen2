%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2018 Sanworks LLC, Stony Brook, New York, USA

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
% Example usage:
% H = HARPSoundCard
% H.loadSound(Index, Waveform, SamplingRate)
%
% Index range: [2 32]
% Waveform: Audio vector with samples in range [-1, 1]
% SamplingRate: Either 96000 or 192000
%
% clear H % Clear object

classdef HARPSoundCard < handle
    properties
        Port
    end
    properties (Access = private)
        Path
        Amp24Bits
    end
    methods
        function obj = HARPSoundCard(varargin)
            if nargin > 0
                portString = varargin{1};
                obj.Port = ArCOMObject_Bpod(portString, 1000000);
            end
            obj.Path = fileparts(which('HarpSoundCard.m'));
            obj.Amp24Bits = pow2(31) - 1;
        end
        function loadSound(obj, Index, Waveform, SamplingRate)
            if Index < 2 || Index > 32
                error('Error: Sound index must be in range [2, 32]')
            end
            Index = round(Index);
            if max(max(Waveform)) > 1 || min(min(Waveform)) < -1
                error('Error: Waveform samples must be in range [-1, 1]')
            end
            if ~(SamplingRate == 96000 || SamplingRate == 192000)
                error('Error: Sampling rate must be either 96000 or 192000')
            end
            [L, W] = size(Waveform);
            if ~((L == 1) || (L == 2))
                error('Error: Waveform must be a 1xn or 2xn vector of samples');
            end
            if L == 1
                Waveform = [Waveform; Waveform];
            end
            Waveform = Waveform*obj.Amp24Bits;
            Waveform = int32(Waveform');
            
            amplitude=1;
            fs=96000;                                   % Sampling frequency
            duration=2;                                 % Seconds
            frequency=1000;                             % Hertz
            time=0:1/fs:duration;
            mono=amplitude*sin(2*pi*frequency*time);    % Create sinewave

            amplitude24bits=pow2(31) - 1;
            stereo=[mono;mono]*amplitude24bits;
            sound_array=stereo(:)';
            Waveform=int32(sound_array);            % Convert array to single precision float
            
            
            fileID = fopen(fullfile(obj.Path, 'tempSoundFile.bin'),'w');
            fwrite(fileID,Waveform,'int32','ieee-le');
            fclose(fileID);
            system(['"' fullfile(obj.Path, 'toSoundCard') '"' ' " ' fullfile(obj.Path,'tempSoundFile.bin') '" ' num2str(Index) ' 0 ' num2str(SamplingRate) ' > NUL']);
        end
        function playSound(obj, soundIndex)
            if isempty(obj.Port)
                error('Error: To trigger sounds, you must initialize the HarpSoundCard object with a serial port argument');
            end
            checksum = (298+soundIndex)-256;
            obj.Port.write([2 5 35 255 1 soundIndex checksum], 'uint8');
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    methods (Access = private)

    end
end