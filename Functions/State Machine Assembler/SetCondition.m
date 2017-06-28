%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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
function sma = SetCondition(sma, ConditionNumber, ConditionChannel, ConditionValue)
% Arguments:
% ConditionNumber = 1 to 5, for conditions 1 to 5
% ConditionChannel = Port or input line (e.g. Port1, Wire1, BNC1)
% ConditionValue = 1 (in/high) or 0 (out/low)]

% Example usage:
% sma = SetCondition(sma, 1, 'Port1', 1);
global BpodSystem
if ischar(ConditionValue)
    error('Condition values must be either 0 or 1, for out/low or in/high respectively.')
end
nConditions = length(sma.ConditionChannels);
if ConditionNumber > nConditions
    error(['Only ' num2str(nConditions) ' conditions are available in the current revision.']);
end
sma.ConditionChannels(ConditionNumber) = find(strcmp(ConditionChannel,BpodSystem.StateMachineInfo.InputChannelNames));
sma.ConditionValues(ConditionNumber) = ConditionValue;
sma.ConditionSet(ConditionNumber) = 1;