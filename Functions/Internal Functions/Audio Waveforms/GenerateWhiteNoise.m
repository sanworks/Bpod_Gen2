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
function Waveform = GenerateWhiteNoise(SamplingRate, Duration, Amplitude, nChannels)
% Args:
% Sampling rate of playback system (Hz)
% Duration of waveform (s)
% Amplitude (Full scale, range = 0-1). If amplitude is a 1x2 vector, it encodes amplitude for L+R channels respectively.
Waveform = (1-(rand(nChannels,SamplingRate*Duration)*2)).*Amplitude';