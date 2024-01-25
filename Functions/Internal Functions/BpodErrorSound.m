function BpodErrorSound() 
err = load('BpodErrorSound.mat');
try
    sound(err.BpodErrorSound, 44100);
catch
end