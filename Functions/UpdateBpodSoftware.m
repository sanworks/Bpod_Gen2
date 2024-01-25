%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

% UpdateBpodSoftware() can be used if not using Git to keep the Bpod
% software current. It will back up your existing Bpod_Gen2 folder to
% \Bpod Local\Temp\, erase the original folder, and replace it with the
% current software from the Bpod_Gen2 master branch. Please note that this
% process will not affect the existing contents of \Bpod Local\ (e.g. data,
% calibration and settings) however it will revert any changes you may have
% made to \Bpod_Gen2\.
%
% Arguments: None
% Returns: None
% Example usage: UpdateBpodSoftware;

function UpdateBpodSoftware

warning off

% Check for compatible system
if verLessThan('MATLAB', '8.4')
    error(['Error: The automatic updater requires MATLAB r2014b or newer. ' char(10)...
        'Update your software manually, following the instructions <a href="matlab:web(''https://sanworks.github.io/Bpod_Wiki/install-and-update/software-update/'',''-browser'')">here</a>.'])
end
if ~ispc
    error(['Error: The automatic updater does not yet work on OSX or Linux. ' char(10)...
        'Update your software manually, following the instructions <a href="matlab:web(''https://sanworks.github.io/Bpod_Wiki/install-and-update/software-update/'',''-browser'')">here</a>.'])
end

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

% Check for Internet connectivity
[a,reply]=system('ping -n 1 -w 1000 www.google.com'); % Check for connection
connectConfirmString = 'Received = 1';
if ~contains(reply, connectConfirmString)
     error(['The Bpod updater was not able to access the Internet.' char(10) 'Please make sure your computer has Internet access and try again.']);
end

% Create paths        
BpodPath = fileparts(which('Bpod'));
path = struct;
path.BpodRoot = BpodPath;
path.ParentDir = fileparts(BpodPath);
path.LocalDir = fullfile(path.ParentDir, 'Bpod Local');
path.Functions = fullfile(path.BpodRoot, 'Functions');
addpath(genpath(path.Functions));
tempDir = fullfile(path.LocalDir, 'Temp');

% Check for latest version
currentVersion = BpodSoftwareVersion_Semantic;
latestVersion = [];
[reply, status] = urlread('https://raw.githubusercontent.com/sanworks/Bpod_Gen2/master/Functions/Internal%20Functions/BpodSoftwareVersion_Semantic.m');
verPos = find(reply == '=');
if ~isempty(verPos)
    latestVersion = strtrim(reply(verPos(end)+2:end-2));
end
if ~isempty(latestVersion)
    if CompareBpodVersions(currentVersion, latestVersion) == 0
        error(['No update required - you already have the latest stable version of Bpod: v' verString]);
    end
end

% Generate user prompt
disp(' ');
disp('----Bpod Software Updater Beta----')
disp(['This will update your Bpod software from v' currentVersion ' to v' latestVersion '.']);
disp('A backup copy of your current Bpod_Gen2 folder will be made in: ');
disp(backupDir);
disp('Then, the latest software from Github will replace your current Bpod_Gen2 folder.');
disp(' ');
disp('If you are using Git to keep Bpod software current, please')
disp('do NOT use the updater - use the Git pull command instead.')
disp(' ');
disp('*IMPORTANT*')
disp('Please manually back up your Bpod_Gen2 folder and data')
disp('before you try using the update tool! If you prefer to update')
disp('manually, please follow the instructions <a href="matlab:web(''https://sanworks.github.io/Bpod_Wiki/install-and-update/software-update/'',''-browser'')">here</a>.')
disp(' ');
reply = input('Do you want to proceed with automatic update? (y/n) ', 's');

if lower(reply) == 'y'
    mkdir(tempDir); % Fails silently if it exists

    % Back up current Bpod software
    disp('Backing up current software...')
    backupDir = fullfile(path.LocalDir, 'Temp', 'Backup');
    mkdir(backupDir);
    dateInfo = datestr(now, 30); 
    dateInfo(dateInfo == 'T') = '_';
    thisBackupDir = fullfile(backupDir, ['Bpod_Backup_' dateInfo]);
    copyfile(path.BpodRoot, thisBackupDir);
    disp('Downloading new software...')

    % Download latest master branch
    downloadDir = fullfile(tempDir, 'Download');
    zipFilePath = fullfile(downloadDir, 'Bpod_Gen2.zip');
    mkdir(downloadDir);
    websave(zipFilePath, 'http://github.com/sanworks/Bpod_Gen2/archive/master.zip');
    disp('Extracting new software...')
    unzip(zipFilePath, downloadDir);
    delete(zipFilePath);

    % Remove old files from path
    rmpath(genpath(path.BpodRoot));

    % Delete old files (backed up previously)
    dos_cmd = sprintf( 'rmdir /S /Q "%s"', path.BpodRoot );
    [st, msg] = system(dos_cmd);
    movefile(fullfile(downloadDir, 'Bpod_Gen2-master'), fullfile(path.ParentDir, 'Bpod_Gen2'), 'f');
    systemPath = fullfile(path.BpodRoot, 'Functions');

    % Add files back to MATLAB path
    addpath(path.BpodRoot);
    addpath(genpath(systemPath));
    disp('Update complete!')
else
    disp('Update canceled. Bpod Software NOT updated.')
end