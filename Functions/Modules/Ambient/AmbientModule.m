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

% AmbientModule is a class to interface with the Bpod Ambient Module via USB.
%
% Fields: 
% Port, an ArCOM object to interface with the USB serial port
%
% Methods:
% measures = getMeasurements()  
%                Returns a struct with the following fields:
%                Temperature_C: Ambient temperature (Celsius)
%                Temperature_F: Ambient temperature (Farenheit)
%                AirPressure_mb: Ambient air pressure (millibars)
%                RelativeHumidity: Relative humidity %
% calibration = getCalibration() Returns the calibration offset for each measurement
%
% setCalibration(tempOffsetCelsius, pressureOffset, humidityOffset)
%                Sets the calibration, given as a signed integer to offset each
%                measurement. Calibration is loaded into non-volatile memory, and will
%                persist across power cycles.

classdef AmbientModule < handle
    properties
        Port % ArCOM Serial port
    end
    methods
        function obj = AmbientModule(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
        end
        function data = getMeasurements(obj)
            obj.Port.write('R', 'uint8');
            rawBytes = obj.Port.read(12, 'uint8');
            measurements = typecast(rawBytes, 'single');
            data = struct;
            data.Temperature_C = measurements(1);
            data.Temperature_F = measurements(1)*(9/5)+32;
            data.AirPressure_mb = measurements(2)/100;
            data.RelativeHumidity = measurements(3);
        end
        function calibration = getCalibration(obj)
            calibration = struct;
            obj.Port.write('G', 'uint8');
            cal = typecast(obj.Port.read(12, 'uint8'), 'single');
            calibration.Temperature_C = cal(1);
            calibration.AirPressure_mb = cal(2);
            calibration.RelativeHumidity = cal(3);
        end
        function setCalibration(obj, tempOffsetCelsius, pressureOffset, humidityOffset)
            obj.Port.write('C', 'uint8', [tempOffsetCelsius*1000 pressureOffset humidityOffset*1000], 'int32');
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end