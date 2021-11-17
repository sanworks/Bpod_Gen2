function SweepWave = GenerateSineSweep(SamplingRate, StartFreq, EndFreq, Duration)
t = 0:1/SamplingRate:Duration;
% create swept sine
phaseInit = -90;
SweepWave = chirp(t, StartFreq, Duration, EndFreq, 'linear', phaseInit);