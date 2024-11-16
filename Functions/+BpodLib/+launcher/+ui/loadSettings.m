function loadSettings(BpodSystem, protocolName, subjectName)
% Populate UI with settings files for the selected subject and protocol

settingsFileNames = BpodLib.launcher.findSettings(BpodSystem.Path.DataFolder, protocolName, subjectName);

set(BpodSystem.GUIHandles.SettingsSelector, 'String', settingsFileNames);
set(BpodSystem.GUIHandles.SettingsSelector,'Value',1);

end