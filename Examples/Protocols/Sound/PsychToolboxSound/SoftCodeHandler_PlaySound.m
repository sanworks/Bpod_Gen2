function SoftCodeHandler_PlaySound(soundID)
global BpodSystem
if soundID ~= 255
    BpodSystem.PluginObjects.Sound.play(soundID);
else
    BpodSystem.PluginObjects.Sound.stopAll;
end