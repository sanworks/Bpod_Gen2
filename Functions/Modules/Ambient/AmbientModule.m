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
classdef AmbientModule < handle
    properties
        Port % ArCOM Serial port
    end
    methods
        function obj = AmbientModule(portString)
            obj.Port = ArCOMObject_Bpod(portString, 115200);
        end
        function Data = getMeasurements(obj)
            obj.Port.write('R', 'uint8');
            RawBytes = obj.Port.read(12, 'uint8');
            Measurements = typecast(RawBytes, 'single');
            Data = struct;
            Data.Temperature_C = Measurements(1);
            Data.Temperature_F = Measurements(1)*(9/5)+32;
            Data.AirPressure_mb = Measurements(2)/100;
            Data.RelativeHumidity = Measurements(3);
        end
        function Calibration = getCalibration(obj)
            Calibration = struct;
            obj.Port.write('G', 'uint8');
            Cal = typecast(obj.Port.read(12, 'uint8'), 'single');
            Calibration.Temperature_C = Cal(1);
            Calibration.AirPressure_mb = Cal(2);
            Calibration.RelativeHumidity = Cal(3);
        end
        function setCalibration(obj, tempOffsetCelsius, pressureOffset, humidityOffset)
            obj.Port.write('C', 'uint8', [tempOffsetCelsius*1000 pressureOffset humidityOffset*1000], 'int32');
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
end