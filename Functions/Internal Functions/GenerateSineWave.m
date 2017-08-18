function SineWave = GenerateSineWave(SamplingRate, Frequency, Duration)
% Duration in seconds
dt = 1/SamplingRate;
t = 0:dt:Duration;
SineWave=sin(2*pi*Frequency*t);
