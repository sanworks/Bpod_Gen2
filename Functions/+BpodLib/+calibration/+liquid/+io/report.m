function report(LiquidCal)
% Print report of status of liquid calibration into Command Window
% report(LiquidCal)
%
% Arguments
% ---------
% LiquidCal : BpodLib.calibration.liquid.ValveDataManagerClass or struct

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

% Issue warning if user hasn't calibrated anything
if strcmp(BpodLib.calibration.liquid.io.checkDefaultData(LiquidCal), 'true')
    w = warning('off', 'backtrace');
    warning('BpodLib:liquidcalibration:UnmodifiedData', ['Liquid calibration data is detected as unmodified. '... 
            newline 'Remember to calibrate your valve(s) before performing experiments!'])
    warning(w) % restore warning settings to their original
end

% Print out the date/time when each valve was last calibrated
hasReport = false;
if isa(LiquidCal, 'BpodLib.calibration.liquid.ValveDataManagerClass')
    valveNames = LiquidCal.getValveNames();
    for idx = 1:numel(valveNames)
        valveName = valveNames{idx};
        Valve = LiquidCal.getValve(valveName);
        if ~isempty(Valve.LastDateModified)
            if ~hasReport
                disp('* Calibration Report *')
                hasReport = true;
            end
            ldm = datetime(Valve.LastDateModified);
            delta = datetime('now') - ldm;
            fprintf('%s last updated %s (%.1f days ago)\n', valveName, ldm, round(days(delta), 1))
        end
    end
elseif isa(LiquidCal, 'struct')
    ldm = datetime(LiquidCal(1).LastDateModified, 'ConvertFrom', 'datenum');
    delta = datetime('now') - ldm;
    disp('* Calibration Report *')
    fprintf('Liquid calibration data last updated %s (%.1f days ago)\n', ldm, round(days(delta), 1))
elseif isempty(LiquidCal)
    % fail silently?
end

end