function SoftCodeHandler_PlaySound(SoundID)
if SoundID ~= 255
    PsychToolboxSoundServer('Play', SoundID);
else
    PsychToolboxSoundServer('StopAll');
end