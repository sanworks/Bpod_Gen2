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

% EditState() sdits one parameter of a state in an existing state machine description.
%
% Arguments:
% stateName: The name of the state to edit (char array)
% 
% parameterName: The parameter to edit. It can be ONE of the following:
% 1. 'Timer'
% 2. 'StateChangeConditions'
% 3. 'OutputActions'
%
% parameterValue: The new value of the parameter
%
% Edits do not clear existing parameters - for instance, changing 'Tup' to
% 'State7' for state 'State6' will not affect the matrix's entries for other events in State6.
% To clear a state's parameters (to set all events or outputs to do nothing), use the
% SetState2Default function.
%
% Usage examples:
%  sma = EditState(sma, 'State6', 'StateChangeConditions', {'Tup', 'State7'});
%  sma = EditState(sma, 'Deliver_Stimulus', 'OutputActions', {'LEDState', 0});
%

function sma_out = EditState(sma, stateName, parameterName, parameterValue)

global BpodSystem % Import the global BpodSystem object

targetStateNumber = find(strcmp(stateName,sma.StateNames));
if isempty(targetStateNumber)
    error(['Error: no state called "' stateName '" was found in the state matrix.'])
end
addedBackSignal = 0;
switch parameterName
    case 'Timer'
        if ischar(parameterValue)
            error('State timer durations must be numbers, in seconds')
        end
        if parameterValue < 0
            error('When setting state timers, time (in seconds) must be positive.')
        end
        if parameterValue > 3600
            error('State timers can not exceed 3600s');
        end
        sma.StateTimers(targetStateNumber) = parameterValue;
    case 'StateChangeConditions'
        if ~iscell(parameterValue)
            error(['Incorrect format for state change conditions - must be a cell array of strings.'...
                   'Example: {''Port2Out'', ''WaitForResponse'', ''Tup'', ''ITI''}'])
        end
        nStateChangeConditions = length(parameterValue);
        for x = 1:2:nStateChangeConditions
            eventNames = BpodSystem.StateMachineInfo.EventNames;
            candidateEvent = parameterValue{x};
            candidateEventCode = find(strcmp(candidateEvent,eventNames));
            if sum(strcmp(candidateEvent, BpodSystem.StateMachineInfo.EventNames)) == 0
                error(['Error: ' candidateEvent... 
                       ' is not a valid event name. See BpodSystem.StateMachineInfo for a list of valid events.']);
            end
            redirectedStateNumber = find(strcmp(parameterValue{x+1},sma.StateNames));
            if isempty(redirectedStateNumber)
                if strcmp(parameterValue{x+1}, 'exit') || strcmp(parameterValue{x+1}, '>exit')
                    redirectedStateNumber = 65537;
                elseif strcmp(parameterValue{x+1}, 'back') || strcmp(parameterValue{x+1}, '>back')
                    redirectedStateNumber = 65538;
                    addedBackSignal = 1;
                else
                    error(['Error: the state "' parameterValue{x+1} '" does not exist in the matrix you tried to edit.'])
                end
            end
            if strcmp(candidateEvent, 'Tup') % State timer matrix
                sma.StateTimerMatrix(targetStateNumber) = redirectedStateNumber;
            else
                if length(candidateEvent) > 9 % All timer, counter and condition events have separate matrices
                    testSegment1 = candidateEvent(1:9);
                    if strcmp(testSegment1, 'Condition')
                        conditionNumber = str2double(candidateEvent(10:end));
                        if conditionNumber <= BpodSystem.HW.n.Conditions
                            sma.ConditionMatrix(targetStateNumber,conditionNumber) = redirectedStateNumber;
                        else
                            error(['Error: Only ' num2str(BpodSystem.HW.n.Conditions)... 
                                ' Conditions can be configured with the connected state machine']);
                        end
                    elseif strcmp(testSegment1, 'GlobalCou')
                        counterString = candidateEvent(1:end-4); % Chop off '_End';
                        globalCounterNumber = str2double(counterString(14:end));
                        if globalCounterNumber <= BpodSystem.HW.n.GlobalCounters
                            sma.GlobalCounterMatrix(targetStateNumber,globalCounterNumber) = redirectedStateNumber;
                        else
                            error(['Error: Only ' num2str(BpodSystem.HW.n.GlobalCounters)... 
                                ' Global Counters can be configured with the connected state machine']);
                        end
                    elseif strcmp(testSegment1, 'GlobalTim')
                        testSegment2 = candidateEvent(end-2:end);
                        if strcmp(testSegment2, 'End')
                            timerString = candidateEvent(1:end-4); % Chop off '_End';
                            globalTimerNumber = str2double(timerString(12:end));
                            if globalTimerNumber <= BpodSystem.HW.n.GlobalTimers
                                sma.GlobalTimerEndMatrix(targetStateNumber,globalTimerNumber) = redirectedStateNumber;
                            else
                                error(['Error: Only ' num2str(BpodSystem.HW.n.GlobalTimers)... 
                                    ' Global Timers can be configured with the connected state machine']);
                            end
                        elseif strcmp(testSegment2, 'art')
                            timerString = candidateEvent(1:end-6); % Chop off '_Start';
                            globalTimerNumber = str2double(timerString(12:end));
                            if globalTimerNumber <= BpodSystem.HW.n.GlobalTimers
                                sma.GlobalTimerStartMatrix(targetStateNumber,globalTimerNumber) = redirectedStateNumber;
                            else
                                error(['Error: Only ' num2str(BpodSystem.HW.n.GlobalTimers)... 
                                    ' Global Timers can be configured with the connected state machine']);
                            end
                        else
                            error(['Error: ' candidateEvent... 
                                ' is not a valid event name. See BpodSystem.StateMachineInfo for a list of valid events.']);
                        end
                    else
                        % Default to input matrix
                        sma.InputMatrix(targetStateNumber,candidateEventCode) = redirectedStateNumber;
                    end
                else
                    sma.InputMatrix(targetStateNumber,candidateEventCode) = redirectedStateNumber;
                end
            end
        end
    case 'OutputActions'
        if ~iscell(parameterValue)
            error(['Incorrect format for output actions - must be a cell array of strings.'...
                   'Example: {''LEDState'', ''1'', ''ValveState'', ''3''}'])
        end
        outputChannelNames = BpodSystem.StateMachineInfo.OutputChannelNames;
        metaActions = {'ValveState', 'LED', 'LEDState', 'BNCState', 'WireState', 'Valve'}; 
        % ValveState is a byte whose bits control an array of valves
        for x = 1:2:length(parameterValue)
            metaAction = find(strcmp(parameterValue{x}, metaActions));
            if ~isempty(metaAction)
                value = parameterValue{x+1};
                switch metaAction
                    case 1
                        valvePos = BpodSystem.HW.Pos.Output_Valve;
                        valveLogic = double(dec2bin(value) == '1');
                        valveLogic = valveLogic(end:-1:1);
                        nValvesAddressed = length(valveLogic);
                        if nValvesAddressed > BpodSystem.HW.n.Valves
                            error(['Error: tried to access valve# ' num2str(nValvesAddressed) ' but only '... 
                                num2str(BpodSystem.HW.n.Valves) ' valves exist on the connected state machine.'])
                        else
                            valveLogic = [valveLogic zeros(1,BpodSystem.HW.n.Valves-length(valveLogic))];
                            sma.OutputMatrix(targetStateNumber,valvePos:valvePos+BpodSystem.HW.n.Valves-1) = valveLogic;
                        end
                    case 2
                        if value > 0
                            sma.OutputMatrix(targetStateNumber,BpodSystem.HW.Pos.Output_PWM+value-1) = 255;
                        end
                    case 3
                        for i = 1:BpodSystem.HW.n.Ports
                            sma.OutputMatrix(targetStateNumber,BpodSystem.HW.Pos.Output_PWM+i-1) = bitget(value, i)*255;
                        end
                    case 4
                        for i = 1:BpodSystem.HW.n.BNCOutputs
                            sma.OutputMatrix(targetStateNumber,BpodSystem.HW.Pos.Output_BNC+i-1) = bitget(value, i)*255;
                        end
                    case 5
                        for i = 1:BpodSystem.HW.n.WireOutputs
                            sma.OutputMatrix(targetStateNumber,BpodSystem.HW.Pos.Output_Wire+i-1) = bitget(value, i)*255;
                        end
                    case 6
                        if value > 0
                            sma.OutputMatrix(targetStateNumber,BpodSystem.HW.Pos.Output_Valve+value-1) = 1;
                        end
                end
            else
                targetEventCode = find(strcmp(parameterValue{x}, outputChannelNames));
                if ~isempty(targetEventCode)
                    value = parameterValue{x+1};
                    vLength = length(value);
                    if vLength == 1
                        if (targetEventCode == BpodSystem.HW.Pos.GlobalTimerTrig) ||... 
                                (targetEventCode == BpodSystem.HW.Pos.GlobalTimerCancel)
                            % For backwards compatability, integers specifying
                            % global timers convert to equivalent binary decimals. To
                            % specify binary, use a string of bits.
                            value = 2^(value-1);
                        else
                            value = uint8(value);
                        end
                    else
                        % Assume binary string, convert to decimal
                        if ischar(value) && ((sum(value == '0') + sum(value == '1')) == length(value)) 
                            value = bin2dec(value);
                        else
                            sma.SerialMessageMode = 1;
                            messageIndex = 0;
                            for i = 1:sma.nSerialMessages(targetEventCode)
                                thisMessage = sma.SerialMessages{i};
                                if length(thisMessage) == vLength
                                    if sum(thisMessage == value) == vLength
                                        messageIndex = i;
                                    end
                                end
                            end
                            if messageIndex > 0
                                value = messageIndex;
                            else
                                sma.nSerialMessages(targetEventCode) = sma.nSerialMessages(targetEventCode) + 1;
                                thisMessageIndex = sma.nSerialMessages(targetEventCode);
                                sma.SerialMessages{targetEventCode,thisMessageIndex} = uint8(value);
                                value = thisMessageIndex;
                            end
                        end
                    end
                    sma.OutputMatrix(targetStateNumber,targetEventCode) = value;
                else
                    error(['Error: ' parameterValue{x}... 
                        ' is not a valid output action name. See BpodSystem.StateMachineInfo for a list of valid outputs.']);
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
