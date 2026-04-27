function LiquidCal_struct = convertToOldFormat(LiquidCal_obj)
% Convert a LiquidCal object to the legacy struct format
% LiquidCal_struct = convertToOldFormat(LiquidCal_obj)
%
% Arguments
% ---------
% LiquidCal_obj : BpodLib.calibration.liquid.ValveDataManagerClass
%
% Returns
% -------
% LiquidCal_struct : struct
%     Same data but different format

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

LiquidCal_struct = struct('Table', [], 'Coeffs', [], 'LastDateModified', []);

valveNames = LiquidCal_obj.getValveNames();
assert(numel(valveNames) == 8)

saveTimes = nan(1, 8);

for x = 1:8
    Valve = LiquidCal_obj.getValve(x);
    Table = [Valve.Durations, Valve.Amounts];
    [~, nCols] = size(Table);
    if ~ismember(nCols, [0, 2])
        error('Table is not working as expected.')
    end
    LiquidCal_struct(x).Table = Table;
    LiquidCal_struct(x).Coeffs = Valve.Coeffs;
    ldm = Valve.LastDateModified;
    if ~isempty(ldm)
        saveTimes(x) = datenum(ldm);
    end
end

LiquidCal_struct(1).LastDateModified = max(saveTimes);


end