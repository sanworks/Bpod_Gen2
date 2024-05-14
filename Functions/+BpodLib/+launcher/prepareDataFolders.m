function prepareDataFolders(dataPath, protocolName)

%Make standard folders for this protocol.  This will fail silently if the folders exist
warning off % Suppress warning that directory already exists
mkdir(dataPath, protocolName);
mkdir(fullfile(dataPath,protocolName,'Session Data'))
mkdir(fullfile(dataPath,protocolName,'Session Settings'))
warning on
% Ensure that a default settings file exists
defaultSettingsFilePath = fullfile(dataPath,protocolName,'Session Settings', 'DefaultSettings.mat');
if ~exist(defaultSettingsFilePath)
    ProtocolSettings = struct;
    save(defaultSettingsFilePath, 'ProtocolSettings')
end

end