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

% SetCondition() configures a Condition that can be used to direct state
% flow. A condition is an assertion about the logic state of a state machine 
% I/O channel or global timer.
%
% Arguments:
% sma = a state machine description that will be modified with the new condition
% conditionNumber = The index of the condition to configure, begining with 1
% conditionChannel = Port or input line (e.g. Port1, Wire1, BNC1); see BpodSystem.StateMachineInfo.InputChannelNames
% conditionValue = 1 (in/high) or 0 (out/low). For global timers, 1 = running, 0 = not running
%
% Returns: sma, the state machine description

% Example usage:
% sma = SetCondition(sma, 1, 'Port1', 1);

function sma = SetCondition(sma, conditionNumber, conditionChannel, conditionValue)

global BpodSystem % Import the global BpodSystem object

% Verify that conditionValue is not char
if ischar(conditionValue)
    error('Condition values must be either 0 or 1, for out/low or in/high respectively.')
end

% Ensure that conditionNumber does not exceed the maximum number of conditions supported
nConditions = length(sma.ConditionChannels);
if conditionNumber > nConditions
    error(['Only ' num2str(nConditions) ' conditions are available with your state machine firmware.']);
end

% Add the condition
channel = find(strcmp(conditionChannel,BpodSystem.StateMachineInfo.InputChannelNames));
if isempty(channel)
    if strcmp(conditionChannel(1:11), 'GlobalTimer')
        channel = str2double(conditionChannel(12:end));
        if channel <= BpodSystem.HW.n.GlobalTimers
            sma.ConditionChannels(conditionNumber) = BpodSystem.HW.n.Inputs + channel;
        else
            error(['Error: A condition tried to access Global Timer ' num2str(channel)... 
                ' but only ' num2str(BpodSystem.HW.n.GlobalTimers) ' global timers exist.'])
        end
    else
        error('Error: Condition channel must be a valid channel or global timer. See BpodSystem.StateMachineInfo.InputChannelNames')
    end
else
    sma.ConditionChannels(conditionNumber) = find(strcmp(conditionChannel, BpodSystem.StateMachineInfo.InputChannelNames));
end
sma.ConditionValues(conditionNumber) = conditionValue;
sma.ConditionSet(conditionNumber) = 1;
