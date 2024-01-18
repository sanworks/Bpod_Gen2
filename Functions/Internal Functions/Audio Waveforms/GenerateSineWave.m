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

% GenerateSineWave() returns a sampled sine waveform 
%
% Arguments:
% samplingRate: sampling rate of the system that will play the sound. Unit = Hz
% frequency: The frequency of the sine waveform. Unit = Hz
% duration: The duration of the waveform. Unit = seconds
%
% Returns:
% sineWave: The sine waveform. Samples range in amplitude between [-1, 1].


function sineWave = GenerateSineWave(samplingRate, frequency, duration)
dt = 1/double(samplingRate);
t = dt:dt:duration;
sineWave=sin(2*pi*frequency*t);
