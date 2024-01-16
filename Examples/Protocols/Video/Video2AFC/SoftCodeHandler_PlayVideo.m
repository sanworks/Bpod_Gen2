function SoftCodeHandler_PlayVideo(vidID)
global BpodSystem
if vidID ~= 255
    BpodSystem.PluginObjects.V.play(vidID);
else
    BpodSystem.PluginObjects.V.stop;
end