function launchCalibrator(BpodSystem)
% Launch the liquid calibrator UI for port array data
% launchCalibrator(BpodSystem)
%
% Arguments
% ---------
% BpodSystem : BpodObject

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

savePath = fullfile(BpodLib.path.getPath('liquidcalibration', BpodSystem), 'LiquidCalibration-PortArrays.json');
if isempty(BpodSystem.CalibrationTables.PortArrays)
    error('BpodLib:portarraylaunchCalibrator:NoData', "No existing port array data found, did you mean BpodLib.calibration.liquid.portarray.initialize(BpodSystem) ?")
end

BpodLib.calibration.liquid.LiquidCalibratorUI(BpodSystem.CalibrationTables.PortArrays, 'BpodSystem', BpodSystem, 'savepath', savePath, 'source', 'portarray');