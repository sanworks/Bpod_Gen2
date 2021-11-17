%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2021 Sanworks LLC, Rochester, New York, USA

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
function setAnalogThresholds(obj, param, values)
% param = 'Threshold1' to set threshold1 for each FlexIO channel
%         'Threshold2' to set threshold2 for each FlexIO channel
%         'Polarity1' to set polarity of threshold1 for each FlexIO channel
%         'Polarity2' to set polarity of threshold2 for each FlexIO channel
%         'Mode' to set mode (0 = independent thresholds manually re-enabled, 
%                             1 = thresholds re-enable each other
%
% values = Threshold (in bits, total 0-5V range = 12 bits, 0-4095)
%          Polarity (0 or 1)
%          Mode (0 or 1)

switch param
    case 'Threshold1'
        obj.AnalogThresholdConfig.Threshold1 = values;
        obj.SerialPort.write('t', 'uint8', [obj.AnalogThresholdConfig.Threshold1 obj.AnalogThresholdConfig.Threshold2], 'uint16');
        obj.SerialPort.read(1, 'uint8'); % Confirm
    case 'Threshold2'
        obj.AnalogThresholdConfig.Threshold2 = values;
        obj.SerialPort.write('t', 'uint8', [obj.AnalogThresholdConfig.Threshold1 obj.AnalogThresholdConfig.Threshold2], 'uint16');
        obj.SerialPort.read(1, 'uint8'); % Confirm
    case 'Polarity1'
        obj.AnalogThresholdConfig.Polarity1 = values;
        obj.SerialPort.write(['p' obj.AnalogThresholdConfig.Polarity1 obj.AnalogThresholdConfig.Polarity2], 'uint8');
        obj.SerialPort.read(1, 'uint8'); % Confirm
    case 'Polarity2'
        obj.AnalogThresholdConfig.Polarity2 = values;
        obj.SerialPort.write(['p' obj.AnalogThresholdConfig.Polarity1 obj.AnalogThresholdConfig.Polarity2], 'uint8');
        obj.SerialPort.read(1, 'uint8'); % Confirm
    case 'Mode'
        obj.AnalogThresholdConfig.Mode = values;
        obj.SerialPort.write(['m' obj.AnalogThresholdConfig.Mode], 'uint8');
        obj.SerialPort.read(1, 'uint8'); % Confirm
end
