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

% BpodObject.analogThresholdEnable() enables or disables the voltage threshold of a
% FlexIO channel configured as analog input.
%
% Arguments:
% channel = FlexIO channel index (int in range 1,4)
% thresholdIndex = index of threshold to set (int in range 1,2)
% value = disabled (0) or enabled (1)

function analogThresholdEnable(obj, channel, thresholdIndex, value)

% Constrain value
if value > 1
    value = 1; % Must be enabled or disabled
end

% Sync with device
obj.SerialPort.write(['e' channel-1 thresholdIndex-1 value], 'uint8');
obj.SerialPort.read(1, 'uint8'); % Confirm