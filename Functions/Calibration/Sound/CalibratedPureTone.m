%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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
function SoundData = CalibratedPureTone(Frequency, Duration, Intensity, Side, RampDuration, SamplingFreq, CalibrationData)
% This function generates a calibrated pure tone for upload to a sound server.
%
% The tone is specified by: Frequency (Hz), Duration (s), Intensity (dB), Side (0=left, 1=right, 2=both).
% A linear intensity ramp is applied to the start and end of the tone,
% defined by RampDuration (s). Use 0 for no ramp.
%
% Additional required arguments are: SamplingFreq (Sampling Frequency of
% the sound server in Hz), and CalibrationData (also stored in BpodSystem.CalibrationTables.SoundCal)
nChannels = length(CalibrationData);
nSamples = Duration*SamplingFreq;
nRampSamples = RampDuration*SamplingFreq;
if nRampSamples >= nSamples/2
    error('Error: ramp duration (in seconds) cannot exceed half of the sound duration');
end
switch Side
    case 0
        UseLeft = 1;
        UseRight = 0;
    case 1
        if nChannels > 1
            UseLeft = 0;
            UseRight = 1;
        else
            error('Error: Calibration file only has data for one (left) channel.')
        end
    case 2
        if nChannels > 1
            UseLeft = 1;
            UseRight = 1;
        else
            error('Error: Calibration file only has data for one (left) channel.')
        end
end
    
if (UseLeft)
    toneAttLeft = polyval(CalibrationData(1,1).Coefficient,Frequency);
    attFactorLeft = toneAttLeft * sqrt(10^((Intensity - CalibrationData(1,1).TargetSPL)/10));
    SoundVecLeft = attFactorLeft * sin(2*pi*Frequency*(1/SamplingFreq:1/SamplingFreq:Duration));
    if nRampSamples > 0
        RampEnvelope = ones(1,nSamples);
        RampEnvelope(1:nRampSamples) = 1/nRampSamples:1/nRampSamples:1;
        RampEnvelope(nSamples-nRampSamples+1:nSamples) = 1:-1/nRampSamples:1/nRampSamples;
        SoundVecLeft = SoundVecLeft.*RampEnvelope;
    end
end
if (UseRight)
    toneAttRight = polyval(CalibrationData(1,2).Coefficient,Frequency);
    attFactorRight = toneAttRight * sqrt(10^((Intensity - CalibrationData(1,2).TargetSPL)/10));
    SoundVecRight = attFactorRight * sin(2*pi*Frequency*(0:1/SamplingFreq:Duration));
    if nRampSamples > 0
        
    end
end

switch Side
    case 0
        SoundData = [SoundVecLeft; zeros(1,nSamples)];
    case 1
        SoundData = [zeros(1,nSamples); SoundVecRight];
    case 2
        SoundData = [SoundVecLeft; SoundVecRight];
end
