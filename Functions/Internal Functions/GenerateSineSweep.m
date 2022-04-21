function SweepWave = GenerateSineSweep(SamplingRate, StartFreq, EndFreq, Duration)
t=1/SamplingRate:1/SamplingRate:Duration;

% Using Statistics toolbox -----------------------------------------------
% phaseInit = -90;
% SweepWave = chirp(t, StartFreq, Duration, EndFreq, 'linear', phaseInit);
% ------------------------------------------------------------------------

% The much less expensive way
k=(EndFreq-StartFreq)/(Duration-t(1));
SweepWave=cos(2*pi*(k/2*t+StartFreq).*t+(pi/2));