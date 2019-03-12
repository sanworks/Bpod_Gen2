function SoftCodeHandler_PlaySound(SoundID)
global BpodSystem
if SoundID ~= 255
    BpodSystem.PluginObjects.Sound.play(SoundID);
else
    BpodSystem.PluginObjects.Sound.stopAll;
end