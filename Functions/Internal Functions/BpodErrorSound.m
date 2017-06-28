function BpodErrorSound()
try
    ErrorSound = audioread('BpodError.wav');
catch
    ErrorSound = wavread('BpodError.wav');
end
try
sound(ErrorSound, 44100);
catch
end