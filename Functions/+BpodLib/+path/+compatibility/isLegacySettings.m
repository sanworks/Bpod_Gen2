function islegacy =  isLegacySettings(LocalDir)
% Check if the settings directory is a legacy one
% islegacy = isLegacySettings(LocalDir)
%
% Arguments
% ---------
% LocalDir : char
%     Path to Bpod Local/
%
% Returns
% -------
% islegacy : logical

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

islegacy = false;

if isfolder(fullfile(LocalDir, 'Config'))
    % If the Config folder exists, it is a legacy settings directory
    islegacy = false;
    return
end

% Check if the Settings folder exists in the LocalDir
if isfolder(fullfile(LocalDir, 'Settings'))
    if ~isfile(fullfile(LocalDir, 'Settings', 'files moved to Config folder.txt'))
        % If the BpodSettings.mat file exists, it is a legacy settings directory
        islegacy = true;
        return
    end
    if isfile(fullfile(LocalDir, 'Settings', 'BpodSettings.mat'))
        % If the BpodSettings.mat file exists, it is a legacy settings directory
        islegacy = true;
        return
    end
end

% Revert to checking for the legacy Calibration Files directory
if isfolder(fullfile(LocalDir, 'Calibration Files'))
    if isfile(fullfile(LocalDir, 'Calibration Files', 'LiquidCalibration.mat'))
        % If the LiquidCalibration.mat file exists, it is a legacy settings directory
        islegacy = true;
        return
    end
end

% error('BpodLib:setup:isLegacySettings', 'LocalDir does not contain a valid Bpod settings directory. Please check the LocalDir path.');
end