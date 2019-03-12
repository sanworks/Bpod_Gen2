%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2019 Sanworks LLC, Stony Brook, New York, USA

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
% ConditionNumber = 1 to n, for conditions 1 to n
% ConditionChannel = Port or input line (e.g. Port1, Wire1, BNC1); see BpodSystem.StateMachineInfo.InputChannelNames
% ConditionValue = 1 (in/high) or 0 (out/low)]

% Example usage:
% sma = SetCondition(sma, 1, 'Port1', 1);
global BpodSystem
if ischar(ConditionValue)
    error('Condition values must be either 0 or 1, for out/low or in/high respectively.')
end
nConditions = length(sma.ConditionChannels);
if ConditionNumber > nConditions
    error(['Only ' num2str(nConditions) ' conditions are available with your state machine firmware.']);
end
Channel = find(strcmp(ConditionChannel,BpodSystem.StateMachineInfo.InputChannelNames));
if isempty(Channel)
    if strcmp(ConditionChannel(1:11), 'GlobalTimer')
        Channel = str2double(ConditionChannel(12:end));
        if Channel <= BpodSystem.HW.n.GlobalTimers
            sma.ConditionChannels(ConditionNumber) = BpodSystem.HW.n.Inputs + Channel;
        else
            error(['Error: A condition tried to access Global Timer ' num2str(Channel) ' but only ' num2str(BpodSystem.HW.n.GlobalTimers) ' global timers exist.'])
        end
    else
        error('Error: Condition channel must be a valid channel or global timer. See BpodSystem.StateMachineInfo.InputChannelNames')
    end
else
    sma.ConditionChannels(ConditionNumber) = find(strcmp(ConditionChannel,BpodSystem.StateMachineInfo.InputChannelNames));
end
sma.ConditionValues(ConditionNumber) = ConditionValue;
sma.ConditionSet(ConditionNumber) = 1;