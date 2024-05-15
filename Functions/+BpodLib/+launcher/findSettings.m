function settingsFileNames = findSettings(dataFolder, protocolName, subjectName)
% Find all settings files in the Settings folder for a given protocol and subject

settingsPath = fullfile(dataFolder, subjectName, protocolName, 'Session Settings');
candidates = dir(settingsPath);
nSettingsFiles = 0;
settingsFileNames = cell(1);
for x = 3:length(candidates)
    extension = candidates(x).name;
    extension = extension(end-2:end);
    if strcmp(extension, 'mat')
        nSettingsFiles = nSettingsFiles + 1;
        name = candidates(x).name;
        settingsFileNames{nSettingsFiles} = name(1:end-4);
    end
end

end