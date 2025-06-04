function saveSettingsBackup(LocalDir, varargin)
%saveSettingsBackup(LocalDir)

p = inputParser();
p.addParameter('verbose', true, @islogical);
p.parse(varargin{:});
if ~isfolder(LocalDir)
    error('LocalDir must be a valid directory path.');
end

backFolderName = sprintf('SettingsBackup_%s', BpodLib.utils.isotime('path'));
backupFolder = fullfile(LocalDir, backFolderName);

mkdir(backupFolder);
if p.Results.verbose
    fprintf('Creating backup of Settings/ and Calibration Files/ in %s\n', backupFolder);
end
copyfile(fullfile(LocalDir, 'Settings'), fullfile(backupFolder, 'Settings'));
copyfile(fullfile(LocalDir, 'Calibration Files'), fullfile(backupFolder, 'Calibration Files'));
end