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
function SoundData = CalibratedPureTone(Frequency, ToneDuration, Intensity, Side, RampDuration, SamplingFreq, CalibrationData)
% This function generates a calibrated pure tone for upload to a sound server.
%
% The tone is specified by: Frequency (Hz), ToneDuration (s), Intensity (dB), Side (0=left, 1=right, 2=both).
% A linear intensity ramp is applied to the start and end of the tone,
% defined by RampDuration (s). Use 0 for no ramp.
%
% Additional required arguments are: SamplingFreq (Sampling Frequency of
% the sound server in Hz), and CalibrationData (also stored in BpodSystem.CalibrationTables.SoundCal)
%
% 12/2023: This function now supports piecewise interpolation. The current version of SoundCalibration_Manual() 
% generates a calibration function using griddedInterpolant() instead of polynomial fitting with polyfit().
% This method better captures the nuanced frequency response of speakers.
% New calibration files have an Interpolant field instead of the Coefficient field.
% Old calibration files are supported, and will automatically use polyfit. A warning will urge the user to recalibrate. 

nChannels = length(CalibrationData);
nSamples = ToneDuration*SamplingFreq;
nRampSamples = RampDuration*SamplingFreq;
if nRampSamples >= nSamples/2
    error('Error: ramp duration (in seconds) cannot exceed half of the sound duration');
end
useInterpolant = true;
if isfield(CalibrationData, 'Coefficient')
    useInterpolant = false;
    warning('Legacy Audio Calibration file detected. Please recalibrate for improved performance.')
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

RampEnvelope = ones(1,nSamples);
if nRampSamples > 0
    RampEnvelope(1:nRampSamples) = 1/nRampSamples:1/nRampSamples:1;
    RampEnvelope(nSamples-nRampSamples+1:nSamples) = 1:-1/nRampSamples:1/nRampSamples;
    
end
    
if (UseLeft)
    if useInterpolant
        toneAttLeft = CalibrationData(1,1).Interpolant(Frequency);
    else
        toneAttLeft = polyval(CalibrationData(1,1).Coefficient,Frequency);
    end
    attFactorLeft = toneAttLeft * sqrt(10^((Intensity - CalibrationData(1,1).TargetSPL)/10));
    SoundVecLeft = attFactorLeft * sin(2*pi*Frequency*(1/SamplingFreq:1/SamplingFreq:ToneDuration));
    SoundVecLeft = SoundVecLeft.*RampEnvelope;
end
if (UseRight)
    if useInterpolant
        toneAttRight = CalibrationData(1,2).Interpolant(Frequency);
    else
        toneAttRight = polyval(CalibrationData(1,2).Coefficient,Frequency);
    end
    attFactorRight = toneAttRight * sqrt(10^((Intensity - CalibrationData(1,2).TargetSPL)/10));
    SoundVecRight = attFactorRight * sin(2*pi*Frequency*(1/SamplingFreq:1/SamplingFreq:ToneDuration));
    SoundVecRight = SoundVecRight.*RampEnvelope;
end

switch Side
    case 0
        SoundData = [SoundVecLeft; zeros(1,nSamples)];
    case 1
        SoundData = [zeros(1,nSamples); SoundVecRight];
    case 2
        SoundData = [SoundVecLeft; SoundVecRight];
end
