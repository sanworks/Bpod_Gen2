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

% readAmbientMetrics() reads temperature, pressure and humidity from the
% Bpod Ambient module, via its connection to the state machine. This is 
% ideal for setups where the ambient module is powered by the State Machine 
% and is not separately connected via USB.
%
% Optional Arguments
% sensor2Read: The index of the sensor to read, if multiple
% ambient modules are connected. Default = 1.
%
% Returns
% measures: A struct with ambient measurements. Fields are:
%           Temperature_C: Ambient temperature (Celsius)
%           Temperature_F: Ambient temperature (Farenheit)
%           AirPressure_mb: Ambient air pressure (millibars)
%           RelativeHumidity: Relative humidity %

function measures = readAmbientMetrics(varargin)

global BpodSystem % Import the global BpodSystem object

% Resolve sensor to read
sensor2Read = 1;
if nargin > 0
    sensor2Read = varargin{1};
    if sensor2Read > 3 || sensor2Read < 1
        sensor2Read = 1;
    else
        sensor2Read = round(sensor2Read);
    end
end

% Ensure that the ambient module is present
moduleName = ['AmbientModule' num2str(sensor2Read)];
if sum(strcmp(BpodSystem.Modules.Name, moduleName)) ~= 1
    error('Error: Could not find an ambient module connected to the Bpod state machine.')
end

% Start the state machine module relay, to read bytes sent from the module
% to the state machine
BpodSystem.StartModuleRelay(moduleName);

% Request measurements
ModuleWrite(moduleName, 'R', 'uint8');

% Read and format measurements
measures = struct;
reply = ModuleRead(moduleName, 12, 'uint8');
measures.Temperature_C  = typecast(reply(1:4), 'single');
measures.Temperature_F = measures.Temperature_C *(9/5)+32;
measures.AirPressure_mb  = typecast(reply(5:8), 'single')/100;
measures.RelativeHumidity  = typecast(reply(9:12), 'single');

% Stop module relay
BpodSystem.StopModuleRelay;
