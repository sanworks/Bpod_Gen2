function SineWave = GenerateSineWave(SamplingRate, Frequency, Duration)
% Duration in seconds
dt = 1/double(SamplingRate);
t = dt:dt:Duration;
SineWave=sin(2*pi*Frequency*t);
