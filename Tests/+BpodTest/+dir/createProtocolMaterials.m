function createProtocolMaterials(varargin)
% Create dummy materials for protocol testing
% createProtocolMaterials(folderPath, protocolName, 'subjectName', _, 'dataFolder', _)
%
% Arguments
% ---------
% folderPath : char
%   Path to the folder where the protocol materials will be created
% protocolName : char
%   Name of the protocol
%
% Keyword Arguments
% -----------------
% subjectName : char (optional, default: 'FakeSubject')
%   Name of the subject
% dataFolder : char | logical (optional, default: true)
%   Path to the data folder or a logical indicating whether to create a data folder for the subject.

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
p.addRequired('folderPath')
p.addRequired('protocolName')
p.addParameter('subjectName', 'FakeSubject')
p.addParameter('dataFolder', true, @(x) ischar(x) || islogical(x)); % str or logical
p.parse(varargin{:})

folderPath = p.Results.folderPath;
protocolName = p.Results.protocolName;
subjectName = p.Results.subjectName;
dataFolder = p.Results.dataFolder;

if islogical(dataFolder) && dataFolder
    makeData = true;
    % go up until folder ends with folderPath
    while true
        [parentFolder, folderName] = fileparts(folderPath);
        if strcmp(folderName, 'Bpod Local')
            break
        end
        dataFolder = fullfile(parentFolder, 'Data');
    end
elseif islogical(dataFolder) && ~dataFolder
    makeData = false;
elseif ischar(dataFolder)
    makeData = true;
else
    error('dataFolder must be a logical or a string')
end

%% Create a protocol file
mkdir(fullfile(folderPath, protocolName));
fileID = fopen(fullfile(folderPath, protocolName, [protocolName '.m']), 'w');
filestr = ['function ' protocolName '\n disp("This is a protocol file.");'];
fprintf(fileID, filestr);
fclose(fileID);

%% Make the data
if ~makeData
    return
end
BpodTest.dir.createDataFolder(dataFolder, subjectName, protocolName);