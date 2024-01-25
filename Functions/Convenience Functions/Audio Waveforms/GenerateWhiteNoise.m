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

% GenerateWhiteNoise() returns a sampled white noise waveform.
%
% Arguments:
% samplingRate: sampling rate of the system that will play the sound. Unit = Hz
% duration: The duration of the waveform. Unit = seconds
% amplitude: The waveform amplitude. Unit = fraction of full scale in range [0,1]
%            If amplitude is a 1x2 vector, it encodes amplitude for L+R channels respectively.
% nChannels: The number of channels
%
% Returns:
% waveform: The white noise waveform

function waveform = GenerateWhiteNoise(samplingRate, duration, amplitude, nChannels)
% Args:
% Sampling rate of playback system (Hz)
% Duration of waveform (s)
% Amplitude (Full scale, range = 0-1). If amplitude is a 1x2 vector, it encodes amplitude for L+R channels respectively.
waveform = (1-(rand(nChannels,samplingRate*duration)*2)).*amplitude';
