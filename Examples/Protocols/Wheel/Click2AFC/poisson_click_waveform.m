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
   

function [waveform, waveParams] = poisson_click_waveform(clickBalance, clickRate, soundDuration,... 
                                                       samplingRate, clickAmplitude, maskIntensity)
% Inputs:
% ClickBalance: the signed balance between click speed for L+R channels
% ClickRate: total click rate (Hz) to divide between L+R channels
% SoundDuration: Total duration of the stimulus train (s)
% SamplingRate: Sampling rate of the playback device (Hz)
% ClickAmplitude: Each click is a biphasic square pulse with amplitude of +/- this value. 
%                 Units = Fraction of full scale output. 
% MaskIntensity: White noise added to the waveform as a background noise mask. Units = Fraction of full scale output.

% Outputs:
% Waveform: a 2xn vector of samples
% WaveParams: a struct containing the click onset times and any input params necessary to reconstruct the 
%             stimulus waveform from click times

nSamples = soundDuration*samplingRate;
nSamplesPerClickPhase = 2; % Each click is a biphasic square waveform with a positive phase followed by a negative phase of the same length
waveform = (1-(rand(2,nSamples)*2))*maskIntensity;
clickRateHalf = clickRate/2;
clickRateL = clickRateHalf + (clickRateHalf*clickBalance);
clickRateR = clickRateHalf - (clickRateHalf*clickBalance);
leftClickTimes = round(cumsum((-log(rand(1,soundDuration*clickRate*10)))*(1/clickRateL) * samplingRate));
rightClickTimes = round(cumsum((-log(rand(1,soundDuration*clickRate*10)))*(1/clickRateR) * samplingRate));
leftClickTimes(leftClickTimes>nSamples-3) = [];
rightClickTimes(rightClickTimes>nSamples-3) = [];
for i = 0:nSamplesPerClickPhase-1
    waveform(1,leftClickTimes+i) = clickAmplitude;
    waveform(2,rightClickTimes+i) = clickAmplitude;
end
for i = 0:nSamplesPerClickPhase-1
    waveform(1,leftClickTimes+i+nSamplesPerClickPhase) = -clickAmplitude;
    waveform(2,rightClickTimes+i+nSamplesPerClickPhase) = -clickAmplitude;
end
waveParams = struct;
waveParams.SamplingRate = uint32(samplingRate);
waveParams.nSamplesPerClickPhase = uint8(nSamplesPerClickPhase);
waveParams.ClickAmplitude = clickAmplitude; % Fraction of full scale output
waveParams.NoiseMaskIntensity = maskIntensity; % Fraction of full scale output
waveParams.LeftClickTimes = leftClickTimes; % Click times (in samples)
waveParams.RightClickTimes = rightClickTimes;
