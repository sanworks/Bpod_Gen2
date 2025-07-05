function LiquidCal = load(varargin)
% Load a calibration file from disk
% liquidData = load(_)
%
% Keyword Arguments
% -----------------
% BpodSystem : BpodObject
%     Whether to display messages in Command Window.
% LocalDir : char
%     LocalDir to use instead of BpodSystem.Path.LocalDir.
%     Must be specified if BpodSystem is not.
% type : char
%     Source to read for the file either 'statemachine' (default) or 'portarray'
%
% Returns
% -------
% liquidData : struct or BpodLib.calibration.liquid.ValveDataManagerClass
%     The liquid data determined to be for the state machine

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
p.addParameter('BpodSystem', [])
p.addParameter('LocalDir', [], @(x) isempty(x) || ischar(x) || isstring(x))
p.addParameter('type', [])
p.parse(varargin{:})
BpodSystem = p.Results.BpodSystem;

switch lower(p.Results.type)
    case 'statemachine'
        filename = 'LiquidCalibration.json';
    case 'portarray'
        filename = 'LiquidCalibration-PortArrays.json';
    otherwise
        error('BpodLib:LiquidCalibration:UnrecognisedType', "Load type '%s' not recognised, should be 'statemachine' or 'portarray'", p.Results.type)
end

LocalDir = BpodLib.path.getPath('local', BpodSystem, 'LocalDir', p.Results.LocalDir);

calibrationFolderpath = BpodLib.path.getPath('liquidcalibration', BpodSystem, 'LocalDir', LocalDir);
legacyPath = fullfile(LocalDir, 'Calibration Files/LiquidCalibration.mat');
expectedFilepath = fullfile(calibrationFolderpath, filename);

% Verify that file structure is as expected
isLegacy = isfile(legacyPath);
isJSON = isfile(fullfile(calibrationFolderpath, 'LiquidCalibration.json'));
isMulti = BpodLib.multi.isMultiSetup(BpodSystem, 'LocalDir', LocalDir);
if isJSON
    if isLegacy
        warning('BpodLib:LiquidCalibrationLoad:LegacyAndJSON', 'Returning LiquidCalibration.json but LiquidCalibration.mat exists, LiquidCalibration.mat should not exist in folder Calibration Files/')
    end
    singleSetupPath = fullfile(BpodLib.path.getPath('liquidcalibration', BpodSystem, 'LocalDir', LocalDir, 'setup', 'single'), 'LiquidCalibration.json');
    if isMulti && isfile(singleSetupPath)
        warning('BpodLib:LiquidCalibrationLoad:MultiAndSingle', 'Bpod detected this is a computer that may have multiple state machines plugged in but found a single-setup liquid calibration file.')
    end
else
    assert(isLegacy, 'Expected legacy .mat file because no .json file was found')
    assert(strcmp(p.Results.type, 'statemachine'), 'BpodLib:LiquidCalibration:PortArrayJSONFail', 'Port Array not supported with old .mat format.')
    LiquidCal = load(legacyPath, 'LiquidCal').LiquidCal;
    % Eventually this should return a warning for being unsupported
    return
end

assert(isfile(expectedFilepath), 'BpodLib:LiquidCalibrationLoad:FileNotFound', 'Liquid calibration file not found at %s', expectedFilepath)

LiquidCal = BpodLib.calibration.liquid.ValveDataManagerClass('filepath', expectedFilepath);

end