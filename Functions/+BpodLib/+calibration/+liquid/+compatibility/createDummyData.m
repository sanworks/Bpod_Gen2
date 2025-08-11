function DummyLiquidCal = createDummyData()
% Create default/dummy LiquidCal object
% DummyValveManager = createDummyData()
%
% This function recreates the data originally shipped with Bpod_Gen2
%
% Returns
% -------
% DummyValveManager : BpodLib.calibration.liquid.ValveDataManagerClass
%     LiquidCal with dummy data

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

DummyLiquidCal = BpodLib.calibration.liquid.ValveDataManagerClass();

% Create valvenames 'Valve1' to 'Valve8'
for i = 1:8
    valveName = sprintf('Valve%d', i);
    DummyLiquidCal.createValve(valveName);
end

% Add some dummy measurements
valve1 = DummyLiquidCal.getValve('Valve1');
valve1.addMeasurement(22, 2);
valve1.addMeasurement(66, 9.5);
valve1.addMeasurement(44, 5);
valve1.addMeasurement(57, 7.5);
valve1.addMeasurement(34, 3.5);

valve3 = DummyLiquidCal.getValve('Valve3');
valve3.addMeasurement(22, 1.5);
valve3.addMeasurement(46, 5.5);
valve3.addMeasurement(59, 7.5);
valve3.addMeasurement(35, 3.5);
valve3.addMeasurement(66, 8.5);

% todo: these dates are different to the .JSON in Examples/
% Update LastDateModified to reflect the dummy data
valve1.LastDateModified = '2016-11-17 16:08:26';  % original from Bpod_Gen2
% valve3.LastDateModified = char(datetime('2024-07-17 09:22:28'));  % the date of this function's creation
valve3.LastDateModified = "";

end