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
   

function [Waveform, WaveParams] = PoissonClickWaveform(ClickBalance, ClickRate, SoundDuration, SamplingRate, ClickAmplitude, MaskIntensity)
% Inputs:
% ClickBalance: the signed balance between click speed for L+R channels
% ClickRate: total click rate (Hz) to divide between L+R channels
% SoundDuration: Total duration of the stimulus train (s)
% SamplingRate: Sampling rate of the playback device (Hz)
% ClickAmplitude: Each click is a biphasic square pulse with amplitude of +/- this value. Units = Fraction of full scale output. 
% MaskIntensity: White noise added to the waveform as a background noise mask. Units = Fraction of full scale output.

% Outputs:
% Waveform: a 2xn vector of samples
% WaveParams: a struct containing the click onset times and any input params necessary to reconstruct the stimulus waveform from click times

nSamples = SoundDuration*SamplingRate;
nSamplesPerClickPhase = 2; % Each click is a biphasic square waveform with a positive phase followed by a negative phase of the same length
Waveform = (1-(rand(2,nSamples)*2))*MaskIntensity;
ClickRateHalf = ClickRate/2;
ClickRateL = ClickRateHalf + (ClickRateHalf*ClickBalance);
ClickRateR = ClickRateHalf - (ClickRateHalf*ClickBalance);
LeftClickTimes = round(cumsum((-log(rand(1,SoundDuration*ClickRate*10)))*(1/ClickRateL) * SamplingRate));
RightClickTimes = round(cumsum((-log(rand(1,SoundDuration*ClickRate*10)))*(1/ClickRateR) * SamplingRate));
LeftClickTimes(LeftClickTimes>nSamples-3) = [];
RightClickTimes(RightClickTimes>nSamples-3) = [];
for i = 0:nSamplesPerClickPhase-1
    Waveform(1,LeftClickTimes+i) = ClickAmplitude;
    Waveform(2,RightClickTimes+i) = ClickAmplitude;
end
for i = 0:nSamplesPerClickPhase-1
    Waveform(1,LeftClickTimes+i+nSamplesPerClickPhase) = -ClickAmplitude;
    Waveform(2,RightClickTimes+i+nSamplesPerClickPhase) = -ClickAmplitude;
end
WaveParams = struct;
WaveParams.SamplingRate = uint32(SamplingRate);
WaveParams.nSamplesPerClickPhase = uint8(nSamplesPerClickPhase);
WaveParams.ClickAmplitude = ClickAmplitude; % Fraction of full scale output
WaveParams.NoiseMaskIntensity = MaskIntensity; % Fraction of full scale output
WaveParams.LeftClickTimes = LeftClickTimes; % Click times (in samples)
WaveParams.RightClickTimes = RightClickTimes;
