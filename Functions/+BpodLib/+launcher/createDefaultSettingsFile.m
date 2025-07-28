function createDefaultSettingsFile(dataFolder, subjectName, protocolName)
% Create a default (empty) settings file for the given subject and protocol
% Only creates the file if it does not already exist

defaultSettingsFilePath = fullfile(dataFolder, subjectName, protocolName, 'Session Settings', 'DefaultSettings.mat');
if ~exist(defaultSettingsFilePath)
    ProtocolSettings = struct;
    save(defaultSettingsFilePath, 'ProtocolSettings')
end

end