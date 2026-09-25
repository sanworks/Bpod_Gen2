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
        sma = setOutputActions(sma, targetStateNumber, stateName, parameterValue);
    otherwise
        error('ParameterName must be one of the following: ''Timer'', ''StateChangeConditions'', ''OutputActions''')
end
sma_out = sma;
if addedBackSignal
    sma_out.meta.use255BackSignal = 1;
end
