function saveSettingsBackup(LocalDir, varargin)
% Save timestamped folder of Settings/ and Calibration Files/ contents
% saveSettingsBackup(LocalDir, _)
%
% Arguments
% ---------
% LocalDir : char
%     Descriptor
%
% Keyword Arguments
% -----------------
% verbose : logical (default=true)
%     Whether to display messages in Command Window.

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