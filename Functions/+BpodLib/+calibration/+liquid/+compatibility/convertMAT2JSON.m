function convertMAT2JSON(BpodSystem, sourcePath, savePath)
% Convert a LiquidCalibration.mat file to a LiquidCalibration.json file
% convertMAT2JSON(BpodSyste, sourcePath, savePath)
%
% Prior to version 1.9.0 liquid calibration data was stored in a .mat file.
% This function converts the .mat to .json
%
% Arguments
% ---------
% BpodSystem : BpodObject
% sourcePath : char
%     Path to the LiquidCalibration.mat file
% savePath : char
%     Path to save the .json file

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

[~, ~, ext] = fileparts(sourcePath);
assert(strcmp(ext, '.mat'), 'File must be a .mat file');

LiquidCal_struct = load(sourcePath, 'LiquidCal').LiquidCal;

nValves = numel(LiquidCal_struct);
if nValves ~= 8
    warning('BpodLib:ValveDataManagerClass:UnexpectedValveNumber', '8 valves expected but %i found. User-modified liquid calibration data likely.', nValves);
end

LiquidCal_obj = BpodLib.calibration.liquid.compatibility.convertFormat(LiquidCal_struct);

LiquidCalSaveData = LiquidCal_obj.createSaveData();
LiquidCalSaveData.metadata.COM = BpodLib.utils.getCurrentCOM(BpodSystem);
BpodLib.calibration.liquid.io.save(LiquidCalSaveData, 'filepath', savePath, 'BpodSystem', BpodSystem);
end