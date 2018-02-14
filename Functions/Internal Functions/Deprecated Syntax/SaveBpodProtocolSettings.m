function SaveBpodProtocolSettings
global BpodSystem
ProtocolSettings = BpodSystem.ProtocolSettings;
save(BpodSystem.Path.Settings, 'ProtocolSettings');