%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Stony Brook, New York, USA

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

function SweepWave = GenerateSineSweep(SamplingRate, StartFreq, EndFreq, Duration)
t=1/SamplingRate:1/SamplingRate:Duration;

% Using Statistics toolbox -----------------------------------------------
% phaseInit = -90;
% SweepWave = chirp(t, StartFreq, Duration, EndFreq, 'linear', phaseInit);
% ------------------------------------------------------------------------

% The much less expensive way
k=(EndFreq-StartFreq)/(Duration-t(1));
SweepWave=cos(2*pi*(k/2*t+StartFreq).*t+(pi/2));