function UpdateBpodSoftware
warning off
% Check for open Bpod
try
    evalin('base', 'BpodSystem;'); % BpodSystem is a global variable in the base workspace, representing the hardware
    isEmpty = evalin('base', 'isempty(BpodSystem);');
    if isEmpty
        evalin('base', 'clear global BpodSystem;')
    else
        error('Cannot update while Bpod is open. Please close the Bpod console and try again.');
    end
catch
end
% Create paths        
BpodPath = fileparts(which('Bpod'));
Path = struct;
Path.BpodRoot = BpodPath;
Path.ParentDir = fileparts(BpodPath);
Path.LocalDir = fullfile(Path.ParentDir, 'Bpod Local');
Path.Functions = fullfile(Path.BpodRoot, 'Functions');
addpath(genpath(Path.Functions));
% Check for latest version
Ver = BpodSoftwareVersion;
latestVersion = [];
[reply, status] = urlread(['https://raw.githubusercontent.com/sanworks/Bpod_Gen2/master/Functions/Internal%20Functions/BpodSoftwareVersion.m']);
verPos = find(reply == '=');
if ~isempty(verPos)
    verString = strtrim(reply(verPos(end)+1:end-1));
    latestVersion = str2double(verString);
end
if ~isempty(latestVersion)
    if Ver == latestVersion 
        error(['No update required - you already have the latest stable version of Bpod: v' verString]);
    end
end

TempDir = fullfile(Path.LocalDir, 'Temp');
mkdir(TempDir); % Fails silently if it exists
% Back up current Bpod software
disp('Backing up current software...')
BackupDir = fullfile(TempDir, 'Backup');
mkdir(BackupDir);
DateInfo = datestr(now, 30); 
DateInfo(DateInfo == 'T') = '_';
ThisBackupDir = fullfile(BackupDir, ['Bpod_Backup_' DateInfo]);
copyfile(Path.BpodRoot, ThisBackupDir);
disp('Downloading new software...')
% Download latest master branch
DownloadDir = fullfile(TempDir, 'Download');
ZipFilePath = fullfile(DownloadDir, 'Bpod_Gen2.zip');
mkdir(DownloadDir);
if verLessThan('MATLAB', '8.4')
    urlwrite('http://github.com/sanworks/Bpod_Gen2/archive/master.zip', ZipFilePath);
else
    websave(ZipFilePath, 'http://github.com/sanworks/Bpod_Gen2/archive/master.zip');
end
disp('Extracting new software...')
unzip(ZipFilePath, DownloadDir);
delete(ZipFilePath);

% Remove old files from path
rmpath(genpath(Path.BpodRoot));
% Delete old files (backed up previously)
dos_cmd = sprintf( 'rmdir /S /Q "%s"', Path.BpodRoot );
[st, msg] = system(dos_cmd);
movefile(fullfile(DownloadDir, 'Bpod_Gen2-master'), fullfile(Path.ParentDir, 'Bpod_Gen2'), 'f');
SystemPath = fullfile(Path.BpodRoot, 'Functions');
addpath(Path.BpodRoot);
addpath(genpath(SystemPath));
disp('Update complete!')