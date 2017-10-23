function BpodErrorSound() 
if verLessThan('matlab', '8')
    ErrorSound = wavread('BpodError.wav');
else
    ErrorSound = audioread('BpodError.wav');
end
try
    sound(ErrorSound, 44100);
catch
end