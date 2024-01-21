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

% GenerateSineSweep() returns a sampled frequency sweep waveform
%
% Arguments:
% samplingRate: sampling rate of the system that will play the sound. Unit = Hz
% startFreq: The initial frequency of the sweep. Unit = Hz
% endFreq: The final frequency of the sweep. Unit = Hz
% duration: The duration of the sweep. Unit = seconds
%
% Returns: sweepWave, the sweep waveform.

function sweepWave = GenerateSineSweep(samplingRate, startFreq, endFreq, duration)

% Compute time vector
t=1/samplingRate:1/samplingRate:duration;

% Using Statistics toolbox -----------------------------------------------
% phaseInit = -90;
% SweepWave = chirp(t, StartFreq, Duration, EndFreq, 'linear', phaseInit);
% ------------------------------------------------------------------------

% The much less expensive way
k=(endFreq-startFreq)/(duration-t(1));
sweepWave=cos(2*pi*(k/2*t+startFreq).*t+(pi/2));
