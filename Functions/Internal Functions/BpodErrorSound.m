function BpodErrorSound() 
Err = load('BpodErrorSound.mat');
try
    sound(Err.BpodErrorSound, 44100);
catch
end