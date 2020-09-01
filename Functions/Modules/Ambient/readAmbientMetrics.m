%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2018 Sanworks LLC, Stony Brook, New York, USA

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

% For setups where the ambient module is powered by State Machine r2 and is
% not separately connected via USB, this function will return ambient
% measures using the state machine as a relay.
function Measures = readAmbientMetrics(varargin)
global BpodSystem
Sensor2Read = 1;
if nargin > 0
    Sensor2Read = varargin{1};
    if Sensor2Read > 3 || Sensor2Read < 1
        Sensor2Read = 1;
    else
        Sensor2Read = round(Sensor2Read);
    end
end
ModuleName = ['AmbientModule' num2str(Sensor2Read)];
if sum(strcmp(BpodSystem.Modules.Name, ModuleName)) ~= 1
    error('Error: Could not find an ambient module connected to the Bpod state machine.')
end
BpodSystem.StartModuleRelay(ModuleName);
ModuleWrite(ModuleName, 'R', 'uint8');
Measures = struct;
Reply = ModuleRead(ModuleName, 12, 'uint8');
Measures.Temperature_C  = typecast(Reply(1:4), 'single');
Measures.Temperature_F = Measures.Temperature_C *(9/5)+32;
Measures.AirPressure_mb  = typecast(Reply(5:8), 'single')/100;
Measures.RelativeHumidity  = typecast(Reply(9:12), 'single');
BpodSystem.StopModuleRelay;