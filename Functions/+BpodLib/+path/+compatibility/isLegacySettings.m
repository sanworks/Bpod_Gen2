function islegacy =  isLegacySettings(LocalDir)
%islegacy = isLegacySettings(LocalDir)
% Check if the settings directory is a legacy one

islegacy = false;

if isfolder(fullfile(LocalDir, 'Config'))
    % If the Config folder exists, it is a legacy settings directory
    islegacy = false;
    return
end

% Check if the Settings folder exists in the LocalDir
if isfolder(fullfile(LocalDir, 'Settings'))
    if isfile(fullfile(LocalDir, 'Settings', 'files moved to Config folder.txt'))
        % If the BpodSettings.mat file exists, it is a legacy settings directory
        islegacy = true;
        return
    end
end
end