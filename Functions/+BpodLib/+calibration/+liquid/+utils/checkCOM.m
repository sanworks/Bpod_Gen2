function matchingCOM = checkCOM(BpodSystem)
% Check if the COM port in the calibration file matches the current BpodSystem COM port.
% matchingCOM = checkCOM(BpodSystem)

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

matchingCOM = 'unknown';
BpodSystemCOM = BpodLib.utils.getCurrentCOM(BpodSystem);
LiquidCal = BpodSystem.CalibrationTables.LiquidCal;

if isempty(LiquidCal)
    % LiquidCal failed to load for some reason
    return
end

if isa(LiquidCal, 'struct')
    % Is a legacy system, no ability to check COM
    return
end

if ~isfield(LiquidCal.metadata, 'COM')
    return
end

if strcmp(LiquidCal.metadata.COM, BpodSystemCOM)
    matchingCOM = 'yes';
else
    matchingCOM = 'no';
end

end