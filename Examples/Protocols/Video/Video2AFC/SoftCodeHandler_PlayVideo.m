function SoftCodeHandler_PlayVideo(VidID)
global BpodSystem
if VidID ~= 255
    BpodSystem.PluginObjects.V.play(VidID);
else
    BpodSystem.PluginObjects.V.stop;
end