%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

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

function Waveform = GenerateSineChord(SamplingRate, Frequencies, Duration, varargin)

% SamplingRate = sampling rate of the system that will play the sound. Unit = Hz
% Frequencies = a vector of frequency components for the chord (e.g. [800 1000 1200]). Unit = Hz
% Duration = duration of sound. Unit = seconds
% Amplitudes (OPTIONAL ARGUMENT) = a vector of fractional amplitudes for each frequency component. (e.g. [0.5 0.25 0.25]). Amplitudes must sum to 1.

nSineWaves = length(Frequencies);
Amplitudes = ones(1,nSineWaves)*(1/nSineWaves);
if nargin > 3
    Amplitudes = varargin{1};
    if length(Amplitudes) ~= nSineWaves
        error('Error using GenerateSineChord: One amplitude must be specified for each frequency component of the chord.');
    end
    if sum(Amplitudes) ~= 1
        error('Error using GenerateSineChord: Vector of amplitudes for each frequency component must sum to 1.');
    end
end

dt = 1/double(SamplingRate);
t = dt:dt:Duration;
Waveform = zeros(1,length(t));

for i = 1:nSineWaves
    Waveform = Waveform + sin(2*pi*Frequencies(i)*t)*Amplitudes(i);
end
