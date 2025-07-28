function prepareDataFolders(subjectDataFolder, protocolName)
% prepareDataFolders(subjectDataFolder, protocolName)
% Make standard folders for this protocol. 
% This will fail silently if the folders exist
% Inputs
% ------
% subjectDataFolder : str
%     Path to the subject data folder (e.g. Bpod_Local/Data/FakeSubject/)
% protocolName : str
%     Name of the protocol

warning off % Suppress warning that directory already exists
mkdir(subjectDataFolder, protocolName);
mkdir(fullfile(subjectDataFolder, protocolName, 'Session Data'))
mkdir(fullfile(subjectDataFolder, protocolName, 'Session Settings'))
warning on

% Ensure that a default settings file exists
[dataFolder, subjectName] = fileparts(subjectDataFolder);
BpodLib.launcher.createDefaultSettingsFile(dataFolder, subjectName, protocolName);

end