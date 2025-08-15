function PortArrayCal = createValveManager(BpodSystem)
% Create an empty Port Array Module liquid calibration manager
% PortArrayCal = createValveManager(BpodSystem)
%
% Arguments
% ---------
% BpodSystem : BpodObject
%
% Returns
% -------
% PortArrayCal : BpodLib.calibration.liquid.ValveDataManagerClass
%     Manager pre-filled with empty eligible port array valves.

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

PortArrayCal = BpodLib.calibration.liquid.ValveDataManagerClass();

for moduleNumber = 1:BpodSystem.Modules.nModules
    for valveIndex = 1:8 % Todo: Only the connected PA's?
        PortArrayCal.createValve(sprintf('PA%i_%i', moduleNumber, valveIndex));
    end
end

end