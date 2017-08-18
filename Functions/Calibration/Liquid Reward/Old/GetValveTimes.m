%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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
function ValveTimes = GetValveTimes(LiquidAmount, TargetValves)
global BpodSystem
nValves = length(TargetValves);
ValveTimes = nan(1,nValves);
for x = 1:nValves
    ValidTable = 1;
    CurrentTable = BpodSystem.CalibrationTables.LiquidCal(TargetValves(x)).Table;
    if ~isempty(CurrentTable)
        ValveDurations = CurrentTable(:,1)';
        nMeasurements = length(ValveDurations);
        if nMeasurements < 2
            ValidTable = 0;
            error(['Not enough liquid calibration measurements exist for valve ' num2str(TargetValves(x)) '. Bpod needs at least 3 measurements.'])
        end
    else
        ValidTable = 0;
        error(['Not enough liquid calibration measurements exist for valve ' num2str(TargetValves(x)) '. Bpod needs at least 3 measurements.'])
    end
    if ValidTable == 1
        ValveTimes(x) = polyval(BpodSystem.CalibrationTables.LiquidCal(TargetValves(x)).Coeffs, LiquidAmount);
        if isnan(ValveTimes(x))
            ValveTimes(x) = 0;
        end
        if any(ValveTimes<0)
            error(['Wrong liquid calibration for valve ' num2str(TargetValves(x)) '. Negative open time.'])
        end
    end
end
ValveTimes = ValveTimes/1000; %Bpod needs at least 3 measurements