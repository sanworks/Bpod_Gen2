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

% AddState() adds a state to an existing state machine description.
%
% Example:
%
%  sma = AddState(sma, ...
%  'Name', 'Deliver_Stimulus', ...
%  'Timer', .001,...
%  'StateChangeConditions', {'Port2Out', 'WaitForResponse', 'Tup', 'ITI'},...
%  'OutputActions', {'LEDState', 1, 'WireState', 3});

function sma_out = AddState(sma, namestr, stateName, timerstr, stateTimer, conditionstr, stateChangeConditions, outputstr, outputActions)

global BpodSystem %% Import the global BpodSystem object

% Sanity check state name
if sum(strcmpi(stateName, {'exit', '>exit'})) > 0
    error('Error: The exit state is added automatically when sending a matrix. Do not add it explicitly.')
end

%% Check whether the new state has already been referenced. Add new blank state to matrix
nStates = length(sma.StatesDefined);
nStatesInManifest = sma.nStatesInManifest;
stateNumber = find(strcmp(stateName, sma.StateNames));
currentStateInManifest = nStatesInManifest + 1;
if sum(sma.StatesDefined) == BpodSystem.StateMachineInfo.MaxStates
    error(['Error: the state matrix can have a maximum of ' num2str(BpodSystem.StateMachineInfo.MaxStates) ' states.'])
end
if strcmp(sma.StateNames{1},'Placeholder')
    currentState = 1;
else
    if isempty(stateNumber) % This state has not been referenced previously
        currentState = nStates+1;
    else % This state was already referenced
        if sma.StatesDefined(stateNumber) == 0
            currentState = stateNumber;
        else
            error(['The state "' stateName '" has already been defined. Edit existing states with the EditState function.'])
        end
    end
end
sma.StateNames{currentState} = stateName;
sma.Manifest{currentStateInManifest} = stateName;
sma.nStatesInManifest = sma.nStatesInManifest + 1;
nInputColumns = sma.meta.InputMatrixSize;
sma.InputMatrix(currentState,:) = BpodSystem.BlankStateMachine.InputMatrix*currentState;
sma.OutputMatrix(currentState,:) = BpodSystem.BlankStateMachine.OutputMatrix;
sma.GlobalTimerStartMatrix(currentState,:) = BpodSystem.BlankStateMachine.GlobalTimerStartMatrix*currentState;
sma.GlobalTimerEndMatrix(currentState,:) = BpodSystem.BlankStateMachine.GlobalTimerEndMatrix*currentState;
sma.GlobalCounterMatrix(currentState,:) = BpodSystem.BlankStateMachine.GlobalCounterMatrix*currentState;
sma.ConditionMatrix(currentState,:) = BpodSystem.BlankStateMachine.ConditionMatrix*currentState;
sma.StateTimerMatrix(currentState) = currentState;
sma.StateTimers(currentState) = stateTimer;
sma.StatesDefined(currentState) = 1;

%% Make sure all the states in "StateChangeConditions" exist, and if not, create them as undefined states.
for x = 2:2:length(stateChangeConditions)
    thisStateName = stateChangeConditions{x};
    [isOp, opCode] = find_op_name(thisStateName); % returns 0 if state name, 1 if special op name (>exit, >back, etc)
    if ~isOp
        isThere = sum(strcmp(thisStateName, sma.StateNames)) > 0;
        if isThere == 0
            newStateNumber = length(sma.StateNames)+1;
            sma.StateNames(newStateNumber) = stateChangeConditions(x);
            sma.StatesDefined(newStateNumber) = 0;
        end
    else
        if opCode == 65538 % True if '>back' is used.
            % Then, only 254 states are allowed and "state 255" is interpreted as a "back" signal
            sma.meta.use255BackSignal = 1;
        end
    end
end

%% Add state transitions
eventNames = BpodSystem.StateMachineInfo.EventNames;
for x = 1:2:length(stateChangeConditions)
    candidateEventCode = find(strcmp(stateChangeConditions{x},eventNames));
    TargetState = stateChangeConditions{x+1};
    [isOp, opCode] = find_op_name(TargetState);
    if isOp
        targetStateNumber = opCode;
    else
        targetStateNumber = find(strcmp(stateChangeConditions{x+1},sma.StateNames));
    end
    if ~isempty(candidateEventCode)
        if candidateEventCode > nInputColumns
            candidateEventName = stateChangeConditions{x};
            if length(candidateEventName) > 4
                EventSuffix = lower(candidateEventName(length(candidateEventName)-3:length(candidateEventName)));
                switch EventSuffix
                    case '_end'
                        if candidateEventCode < nInputColumns+(BpodSystem.HW.n.GlobalTimers*2)+1
                            % This is a transition for a global timer end. Add to global timer end matrix.
                            startPos = length(candidateEventName) - 5; endPos = startPos+1;
                            timerNumString = candidateEventName(startPos:endPos);
                            if lower(timerNumString(1)) == 'r'
                                timerNumString = timerNumString(2);
                            end
                            globalTimerNumber = str2double(timerNumString);
                            if ~isnan(globalTimerNumber)
                                sma.GlobalTimerEndMatrix(currentState, globalTimerNumber) = targetStateNumber;
                            else
                                event_not_found_message(stateChangeConditions{x},stateName);
                            end
                        else
                            % This is a transition for a global counter. Add to global counter matrix.
                            globalCounterNumber = str2double(candidateEventName(length(candidateEventName) - 4));
                            if ~isnan(globalCounterNumber)
                                sma.GlobalCounterMatrix(currentState, globalCounterNumber) = targetStateNumber;
                            else
                                event_not_found_message(stateChangeConditions{x},stateName);
                            end
                        end
                    case 'tart'
                        % This is a transition for a global timer start. Add to global timer start matrix.
                        startPos = length(candidateEventName) - 7; endPos = startPos+1;
                        timerNumString = candidateEventName(startPos:endPos);
                        if lower(timerNumString(1)) == 'r'
                            timerNumString = timerNumString(2);
                        end
                        globalTimerNumber = str2double(timerNumString);
                        if ~isnan(globalTimerNumber)
                            sma.GlobalTimerStartMatrix(currentState, globalTimerNumber) = targetStateNumber;
                        else
                            event_not_found_message(stateChangeConditions{x},stateName);
                        end
                    otherwise
                        % This is a transition for a condition. Add to condition matrix
                        startPos = length(candidateEventName)-1; endPos = startPos+1;
                        condNumString = candidateEventName(startPos:endPos);
                        if lower(condNumString(1)) == 'n'
                            condNumString = condNumString(2);
                        end
                        conditionNumber = str2double(condNumString);
                        if ~isnan(conditionNumber)
                            sma.ConditionMatrix(currentState, conditionNumber) = targetStateNumber;
                        else
                            event_not_found_message(stateChangeConditions{x},stateName);
                        end
                end
            else % Tup
                sma.StateTimerMatrix(currentState) = targetStateNumber;
            end
        else
            sma.InputMatrix(currentState,candidateEventCode) = targetStateNumber;
        end
    else
        event_not_found_message(stateChangeConditions{x}, stateName);
    end
end

%% Add output actions
sma = setOutputActions(sma, currentState, stateName, outputActions);

%% Add self timer
sma.StateTimers(currentState) = stateTimer;

%% Return state matrix
sma_out = sma;

%%%%%%%%%%%%%% End AddState(). Accessory functions below. %%%%%%%%%%%%%%

function event_not_found_message(thisEventName, thisStateName)
error(['Unknown event found: ''' thisEventName ''' in state: ''' thisStateName '''.' char(10)...
    'A list of registered event names is given <a href="matlab:BpodSystemInfo;">here</a>.']);

function [isOp, opCode] = find_op_name(thisStateName)
isOp = false; opCode = 0;
if thisStateName(1) == '>'
    switch thisStateName(2:end)
        case 'exit'
            isOp = true;
            opCode = 65537;
        case 'back'
            isOp = true;
            opCode = 65538;
    end
else
    if length(thisStateName) == 4
        if strcmpi(thisStateName,'exit') % Accept 'exit' without > for backwards compatability
            isOp = true;
            opCode = 65537;
        end
    end
end