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
function sma_out = EditState(sma, StateName, ParameterName, ParameterValue)
% Edits one parameter of a state in an existing state matrix.
%
% ParameterName can be ONE of the following:
% 1. 'Timer'
% 2. 'StateChangeConditions'
% 3. 'OutputActions'
%
% Edits do not clear existing parameters - for instance, changing 'Tup' to
% 'State7' for state 'State6' will not affect the matrix's entries for other events in State6.
% To clear a state's parameters (to set all events or outputs to do nothing), use the
% SetState2Default function.
%
% Examples:
%  sma = EditState(sma, 'State6', 'StateChangeConditions', {'Tup', 'State7'});
%  sma = EditState(sma, 'Deliver_Stimulus', 'OutputActions', {'LEDState', 0});
%
global BpodSystem
TargetStateNumber = find(strcmp(StateName,sma.StateNames));
if isempty(TargetStateNumber)
    error(['Error: no state called "' StateName '" was found in the state matrix.'])
end
addedBackSignal = 0;
switch ParameterName
    case 'Timer'
        if ischar(ParameterValue)
            error('State timer durations must be numbers, in seconds')
        end
        if ParameterValue < 0
            error('When setting state timers, time (in seconds) must be positive.')
        end
        if ParameterValue > 3600
            error('State timers can not exceed 3600s');
        end
        sma.StateTimers(TargetStateNumber) = ParameterValue;
    case 'StateChangeConditions'
        if ~iscell(ParameterValue)
            error('Incorrect format for state change conditions - must be a cell array of strings. Example: {''Port2Out'', ''WaitForResponse'', ''Tup'', ''ITI''}')
        end
        nStateChangeConditions = length(ParameterValue);
        for x = 1:2:nStateChangeConditions
            EventNames = BpodSystem.StateMachineInfo.EventNames;
            CandidateEvent = ParameterValue{x};
            CandidateEventCode = find(strcmp(CandidateEvent,EventNames));
            if sum(strcmp(CandidateEvent, BpodSystem.StateMachineInfo.EventNames)) == 0
                error(['Error: ' CandidateEvent ' is not a valid event name. See BpodSystem.StateMachineInfo for a list of valid events.']);
            end
            RedirectedStateNumber = find(strcmp(ParameterValue{x+1},sma.StateNames));
            if isempty(RedirectedStateNumber)
                if strcmp(ParameterValue{x+1}, 'exit') || strcmp(ParameterValue{x+1}, '>exit')
                    RedirectedStateNumber = 65537;
                elseif strcmp(ParameterValue{x+1}, 'back') || strcmp(ParameterValue{x+1}, '>back')
                    RedirectedStateNumber = 65538;
                    addedBackSignal = 1;
                else
                    error(['Error: the state "' ParameterValue{x+1} '" does not exist in the matrix you tried to edit.'])
                end
            end
            if strcmp(CandidateEvent, 'Tup') % State timer matrix
                sma.StateTimerMatrix(TargetStateNumber) = RedirectedStateNumber;
            else
                if length(CandidateEvent) > 9 % All timer, counter and condition events have separate matrices
                    testSegment1 = CandidateEvent(1:9);
                    if strcmp(testSegment1, 'Condition')
                        conditionNumber = str2double(CandidateEvent(10:end));
                        if conditionNumber <= BpodSystem.HW.n.Conditions
                            sma.ConditionMatrix(TargetStateNumber,conditionNumber) = RedirectedStateNumber;
                        else
                            error(['Error: Only ' num2str(BpodSystem.HW.n.Conditions) ' Conditions can be configured with the connected state machine']);
                        end
                    elseif strcmp(testSegment1, 'GlobalCou')
                        counterString = CandidateEvent(1:end-4); % Chop off '_End';
                        globalCounterNumber = str2double(counterString(14:end));
                        if globalCounterNumber <= BpodSystem.HW.n.GlobalCounters
                            sma.GlobalCounterMatrix(TargetStateNumber,globalCounterNumber) = RedirectedStateNumber;
                        else
                            error(['Error: Only ' num2str(BpodSystem.HW.n.GlobalCounters) ' Global Counters can be configured with the connected state machine']);
                        end
                    elseif strcmp(testSegment1, 'GlobalTim')
                        testSegment2 = CandidateEvent(end-2:end);
                        if strcmp(testSegment2, 'End')
                            timerString = CandidateEvent(1:end-4); % Chop off '_End';
                            globalTimerNumber = str2double(timerString(12:end));
                            if globalTimerNumber <= BpodSystem.HW.n.GlobalTimers
                                sma.GlobalTimerEndMatrix(TargetStateNumber,globalTimerNumber) = RedirectedStateNumber;
                            else
                                error(['Error: Only ' num2str(BpodSystem.HW.n.GlobalTimers) ' Global Timers can be configured with the connected state machine']);
                            end
                        elseif strcmp(testSegment2, 'art')
                            timerString = CandidateEvent(1:end-6); % Chop off '_Start';
                            globalTimerNumber = str2double(timerString(12:end));
                            if globalTimerNumber <= BpodSystem.HW.n.GlobalTimers
                                sma.GlobalTimerStartMatrix(TargetStateNumber,globalTimerNumber) = RedirectedStateNumber;
                            else
                                error(['Error: Only ' num2str(BpodSystem.HW.n.GlobalTimers) ' Global Timers can be configured with the connected state machine']);
                            end
                        else
                            error(['Error: ' CandidateEvent ' is not a valid event name. See BpodSystem.StateMachineInfo for a list of valid events.']);
                        end
                    else
                        % Default to input matrix
                        sma.InputMatrix(TargetStateNumber,CandidateEventCode) = RedirectedStateNumber;
                    end
                else
                    sma.InputMatrix(TargetStateNumber,CandidateEventCode) = RedirectedStateNumber;
                end
            end
        end
    case 'OutputActions'
        if ~iscell(ParameterValue)
            error('Incorrect format for output actions - must be a cell array of strings. Example: {''LEDState'', ''1'', ''ValveState'', ''3''}')
        end
        OutputChannelNames = BpodSystem.StateMachineInfo.OutputChannelNames;
        MetaActions = {'ValveState', 'LED', 'LEDState', 'BNCState', 'WireState', 'Valve'}; % ValveState is a byte whose bits control an array of valves
        for x = 1:2:length(ParameterValue)
            MetaAction = find(strcmp(ParameterValue{x}, MetaActions));
            if ~isempty(MetaAction)
                Value = ParameterValue{x+1};
                switch MetaAction
                    case 1
                        ValvePos = BpodSystem.HW.Pos.Output_Valve;
                        ValveLogic = double(dec2bin(Value) == '1');
                        ValveLogic = ValveLogic(end:-1:1);
                        nValvesAddressed = length(ValveLogic);
                        if nValvesAddressed > BpodSystem.HW.n.Valves
                            error(['Error: tried to access valve# ' num2str(nValvesAddressed) ' but only ' num2str(BpodSystem.HW.n.Valves) ' valves exist on the connected state machine.'])
                        else
                            ValveLogic = [ValveLogic zeros(1,BpodSystem.HW.n.Valves-length(ValveLogic))];
                            sma.OutputMatrix(TargetStateNumber,ValvePos:ValvePos+BpodSystem.HW.n.Valves-1) = ValveLogic;
                        end
                    case 2
                        if Value > 0
                            sma.OutputMatrix(TargetStateNumber,BpodSystem.HW.Pos.Output_PWM+Value-1) = 255;
                        end
                    case 3
                        for i = 1:BpodSystem.HW.n.Ports
                            sma.OutputMatrix(TargetStateNumber,BpodSystem.HW.Pos.Output_PWM+i-1) = bitget(Value, i)*255;
                        end
                    case 4
                        for i = 1:BpodSystem.HW.n.BNCOutputs
                            sma.OutputMatrix(TargetStateNumber,BpodSystem.HW.Pos.Output_BNC+i-1) = bitget(Value, i)*255;
                        end
                    case 5
                        for i = 1:BpodSystem.HW.n.WireOutputs
                            sma.OutputMatrix(TargetStateNumber,BpodSystem.HW.Pos.Output_Wire+i-1) = bitget(Value, i)*255;
                        end
                    case 6
                        if Value > 0
                            sma.OutputMatrix(TargetStateNumber,BpodSystem.HW.Pos.Output_Valve+Value-1) = 1;
                        end
                end
            else
                TargetEventCode = find(strcmp(ParameterValue{x}, OutputChannelNames));
                if ~isempty(TargetEventCode)
                    Value = ParameterValue{x+1};
                    vLength = length(Value);
                    if vLength == 1
                        if (TargetEventCode == BpodSystem.HW.Pos.GlobalTimerTrig) || (TargetEventCode == BpodSystem.HW.Pos.GlobalTimerCancel)
                            % For backwards compatability, integers specifying
                            % global timers convert to equivalent binary decimals. To
                            % specify binary, use a string of bits.
                            Value = 2^(Value-1);
                        else
                            Value = uint8(Value);
                        end
                    else
                        if ischar(Value) && ((sum(Value == '0') + sum(Value == '1')) == length(Value)) % Assume binary string, convert to decimal
                            Value = bin2dec(Value);
                        else
                            sma.SerialMessageMode = 1;
                            messageIndex = 0;
                            for i = 1:sma.nSerialMessages(TargetEventCode)
                                thisMessage = sma.SerialMessages{i};
                                if length(thisMessage) == vLength
                                    if sum(thisMessage == Value) == vLength
                                        messageIndex = i;
                                    end
                                end
                            end
                            if messageIndex > 0
                                Value = messageIndex;
                            else
                                sma.nSerialMessages(TargetEventCode) = sma.nSerialMessages(TargetEventCode) + 1;
                                thisMessageIndex = sma.nSerialMessages(TargetEventCode);
                                sma.SerialMessages{TargetEventCode,thisMessageIndex} = uint8(Value);
                                Value = thisMessageIndex;
                            end
                        end
                    end
                    sma.OutputMatrix(TargetStateNumber,TargetEventCode) = Value;
                else
                    error(['Error: ' ParameterValue{x} ' is not a valid output action name. See BpodSystem.StateMachineInfo for a list of valid outputs.']);
                end
            end
        end
    otherwise
        error('ParameterName must be one of the following: ''Timer'', ''StateChangeConditions'', ''OutputActions''')
end
sma_out = sma;
if addedBackSignal
    sma_out.meta.use255BackSignal = 1;
end
%%%%%%%%%%%%%% End Main Code. Functions below. %%%%%%%%%%%%%%

function EventSpellingErrorMessage(ThisStateName)
error(['Check spelling of your state transition events for state: ' ThisStateName '. Valid events (% is an index): Port%In Port%Out BNC%High BNC%Low Wire%High Wire%Low SoftCode% GlobalTimer%End Tup'])