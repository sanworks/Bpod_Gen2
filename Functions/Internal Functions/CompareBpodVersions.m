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

% CompareBpodVersions() determines whether a software version is ahead or behind
% another version using semantic versioning. 
%
% Arguments: localVersion, remoteVersion. Character arrays specifying
% semantic versions, e.g. XX.XX.XX.
%
% Returns: result (double). -1 if local is behind, 0 if equal, 1 if ahead

function result = CompareBpodVersions(localVersion, remoteVersion)

    % Split the version strings into their components
    parts1 = split(localVersion, '.');
    parts2 = split(remoteVersion, '.');

    % Convert string arrays to numeric arrays
    numParts1 = str2double(parts1);
    numParts2 = str2double(parts2);

    % Compare major, minor, and patch numbers
    for i = 1:min(length(numParts1), length(numParts2))
        if numParts1(i) > numParts2(i)
            result = 1; % version1 is newer
            return;
        elseif numParts1(i) < numParts2(i)
            result = -1; % version2 is newer
            return;
        end
    end

    % If all compared parts are equal, check if any version has additional parts
    if length(numParts1) > length(numParts2)
        result = 1; % version1 is newer
    elseif length(numParts1) < length(numParts2)
        result = -1; % version2 is newer
    else
        result = 0; % versions are equal
    end
end