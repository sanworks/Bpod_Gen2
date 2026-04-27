function LiquidCal_obj = convertFormat(LiquidCal_struct)
% Convert LiquidCal_struct structure to ValveDataManagerClass
% LiquidCal_obj = convertFormat(LiquidCal_struct)
%
% Arguments
% ---------
% LiquidCal_struct : struct
%     LiquidCal_struct : the LiquidCalibration structure
%
% Returns
% -------
% LiquidCal_obj : BpodLib.calibration.liquid.ValveDataManagerClass
%     ValveDataManager object

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

% Create data object and add measurements
LiquidCal_obj = BpodLib.calibration.liquid.ValveDataManagerClass();
nValves = numel(LiquidCal_struct);
for valveNumber = 1:nValves
    % Original data stores valves in nonscalar structure
    valveName = sprintf('Valve%i', valveNumber);
    valveData = LiquidCal_obj.createValve(valveName);
    originalData = LiquidCal_struct(valveNumber);
    nMeasurements = size(originalData.Table, 1);
    for measurementIdx = 1:nMeasurements
        valveData.addMeasurement(originalData.Table(measurementIdx, 1), originalData.Table(measurementIdx, 2));
    end

    % Maintain original calibration datetime
    modifydatetime = datetime(originalData.LastDateModified, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss');
    valveData.LastDateModified = char(modifydatetime);
end

end