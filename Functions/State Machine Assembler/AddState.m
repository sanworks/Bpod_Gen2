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
function sma_out = AddState(sma, namestr, StateName, timerstr, StateTimer, conditionstr, StateChangeConditions, outputstr, OutputActions)
% Adds a state to an existing state matrix.
%
% Example:
%
%  sma = AddState(sma, ...
%  'Name', 'Deliver_Stimulus', ...
%  'Timer', .001,...
%  'StateChangeConditions', {'Port2Out', 'WaitForResponse', 'Tup', 'ITI'},...
%  'OutputActions', {'LEDState', 1, 'WireState', 3, 'SerialCode', 3});

global BpodSystem
% Sanity check state name
if sum(strcmpi(StateName, {'exit', '>exit'})) > 0
    error('Error: The exit state is added automatically when sending a matrix. Do not add it explicitly.')
end

%% Check whether the new state has already been referenced. Add new blank state to matrix
nStates = length(sma.StatesDefined);
nStatesInManifest = sma.nStatesInManifest;
StateNumber = find(strcmp(StateName, sma.StateNames));
CurrentStateInManifest = nStatesInManifest + 1;
if sum(sma.StatesDefined) == BpodSystem.StateMachineInfo.MaxStates
    error(['Error: the state matrix can have a maximum of ' num2str(BpodSystem.StateMachineInfo.MaxStates) ' states.'])
end
if strcmp(sma.StateNames{1},'Placeholder')
    CurrentState = 1;
else
    if isempty(StateNumber) % This state has not been referenced previously
        CurrentState = nStates+1;
    else % This state was already referenced
        if sma.StatesDefined(StateNumber) == 0
            CurrentState = StateNumber;
        else
            error(['The state "' StateName '" has already been defined. Edit existing states with the EditState function.'])
        end
    end
end
sma.StateNames{CurrentState} = StateName;
sma.Manifest{CurrentStateInManifest} = StateName;
sma.nStatesInManifest = sma.nStatesInManifest + 1;
nInputColumns = sma.meta.InputMatrixSize;
sma.InputMatrix(CurrentState,:) = BpodSystem.BlankStateMachine.InputMatrix*CurrentState;
sma.OutputMatrix(CurrentState,:) = BpodSystem.BlankStateMachine.OutputMatrix;
sma.GlobalTimerStartMatrix(CurrentState,:) = BpodSystem.BlankStateMachine.GlobalTimerStartMatrix*CurrentState;
sma.GlobalTimerEndMatrix(CurrentState,:) = BpodSystem.BlankStateMachine.GlobalTimerEndMatrix*CurrentState;
sma.GlobalCounterMatrix(CurrentState,:) = BpodSystem.BlankStateMachine.GlobalCounterMatrix*CurrentState;
sma.ConditionMatrix(CurrentState,:) = BpodSystem.BlankStateMachine.ConditionMatrix*CurrentState;
sma.StateTimerMatrix(CurrentState) = CurrentState;
sma.StateTimers(CurrentState) = StateTimer;
sma.StatesDefined(CurrentState) = 1;

%% Make sure all the states in "StateChangeConditions" exist, and if not, create them as undefined states.
for x = 2:2:length(StateChangeConditions)
    ThisStateName = StateChangeConditions{x};
    [IsOp, opCode] = findOpName(ThisStateName); % returns 0 if state name, 1 if special op name (>exit, >back, etc)
    if ~IsOp
        isThere = sum(strcmp(ThisStateName, sma.StateNames)) > 0;
        if isThere == 0
            NewStateNumber = length(sma.StateNames)+1;
            sma.StateNames(NewStateNumber) = StateChangeConditions(x);
            sma.StatesDefined(NewStateNumber) = 0;
        end
    else
        if opCode == 65538 % True if '>back' is used. Then, only 254 states are allowed and "state 255" is interpreted as a "back" signal
            sma.meta.use255BackSignal = 1;
        end
    end
end
%% Add state transitions
EventNames = BpodSystem.StateMachineInfo.EventNames;
for x = 1:2:length(StateChangeConditions)
    CandidateEventCode = find(strcmp(StateChangeConditions{x},EventNames));
    TargetState = StateChangeConditions{x+1};
    [IsOp, opCode] = findOpName(TargetState);
    if IsOp
        TargetStateNumber = opCode;
    else
        TargetStateNumber = find(strcmp(StateChangeConditions{x+1},sma.StateNames));
    end
    if ~isempty(CandidateEventCode)
        if CandidateEventCode > nInputColumns
            CandidateEventName = StateChangeConditions{x};
            if length(CandidateEventName) > 4
                EventSuffix = lower(CandidateEventName(length(CandidateEventName)-3:length(CandidateEventName)));
                switch EventSuffix
                    case '_end'
                        if CandidateEventCode < nInputColumns+(BpodSystem.HW.n.GlobalTimers*2)+1;
                            % This is a transition for a global timer end. Add to global timer end matrix.
                            StartPos = length(CandidateEventName) - 5; EndPos = StartPos+1;
                            TimerNumString = CandidateEventName(StartPos:EndPos);
                            if lower(TimerNumString(1)) == 'r'
                                TimerNumString = TimerNumString(2);
                            end
                            GlobalTimerNumber = str2double(TimerNumString);
                            if ~isnan(GlobalTimerNumber)
                                sma.GlobalTimerEndMatrix(CurrentState, GlobalTimerNumber) = TargetStateNumber;
                            else
                                EventSpellingErrorMessage(ThisStateName);
                            end
                        else
                            % This is a transition for a global counter. Add to global counter matrix.
                            GlobalCounterNumber = str2double(CandidateEventName(length(CandidateEventName) - 4));
                            if ~isnan(GlobalCounterNumber)
                                sma.GlobalCounterMatrix(CurrentState, GlobalCounterNumber) = TargetStateNumber;
                            else
                                EventSpellingErrorMessage(ThisStateName);
                            end
                        end
                    case 'tart'
                        % This is a transition for a global timer start. Add to global timer start matrix.
                        
                        StartPos = length(CandidateEventName) - 7; EndPos = StartPos+1;
                        TimerNumString = CandidateEventName(StartPos:EndPos);
                        if lower(TimerNumString(1)) == 'r'
                            TimerNumString = TimerNumString(2);
                        end
                        GlobalTimerNumber = str2double(TimerNumString);
                        if ~isnan(GlobalTimerNumber)
                            sma.GlobalTimerStartMatrix(CurrentState, GlobalTimerNumber) = TargetStateNumber;
                        else
                            EventSpellingErrorMessage(ThisStateName);
                        end
                    otherwise
                        % This is a transition for a condition. Add to condition matrix
                        StartPos = length(CandidateEventName)-1; EndPos = StartPos+1;
                        CondNumString = CandidateEventName(StartPos:EndPos);
                        if lower(CondNumString(1)) == 'n'
                            CondNumString = CondNumString(2);
                        end
                        ConditionNumber = str2double(CondNumString);
                        if ~isnan(ConditionNumber)
                            sma.ConditionMatrix(CurrentState, ConditionNumber) = TargetStateNumber;
                        else
                            EventSpellingErrorMessage(ThisStateName);
                        end
                end
            else % Tup
                sma.StateTimerMatrix(CurrentState) = TargetStateNumber;
            end
        else
            sma.InputMatrix(CurrentState,CandidateEventCode) = TargetStateNumber;
        end
    else
        EventSpellingErrorMessage(ThisStateName);
    end
end

%% Add output actions
OutputChannelNames = BpodSystem.StateMachineInfo.OutputChannelNames;
MetaActions = {'ValveState', 'LED', 'LEDState', 'BNCState', 'WireState', 'Valve'}; % ValveState is a byte whose bits control an array of valves

% LED is an alternate syntax for PWM1-8,specifying one LED to set to max brightness (1-8)
% LEDState is an alternate syntax for PWM1-8. A byte coding for binary sets which LEDs are at max brightness
% BNCState and WireState are added for backwards compatability with Bpod
% 0.5. A byte is converted to bits to control logic on the BNC and Wire outputs channel arrays.
for x = 1:2:length(OutputActions)
    MetaAction = find(strcmp(OutputActions{x}, MetaActions));
    if ~isempty(MetaAction)
        Value = OutputActions{x+1};
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
                    sma.OutputMatrix(CurrentState,ValvePos:ValvePos+BpodSystem.HW.n.Valves-1) = ValveLogic;
                end
            case 2
                if Value > 0
                    sma.OutputMatrix(CurrentState,BpodSystem.HW.Pos.Output_PWM+Value-1) = 255;
                end
            case 3
                for i = 1:BpodSystem.HW.n.Ports
                    sma.OutputMatrix(CurrentState,BpodSystem.HW.Pos.Output_PWM+i-1) = bitget(Value, i)*255;
                end
            case 4
                for i = 1:BpodSystem.HW.n.BNCOutputs
                    sma.OutputMatrix(CurrentState,BpodSystem.HW.Pos.Output_BNC+i-1) = bitget(Value, i)*255;
                end
            case 5
                for i = 1:BpodSystem.HW.n.WireOutputs
                    sma.OutputMatrix(CurrentState,BpodSystem.HW.Pos.Output_Wire+i-1) = bitget(Value, i)*255;
                end
            case 6
                if Value > 0
                    sma.OutputMatrix(CurrentState,BpodSystem.HW.Pos.Output_Valve+Value-1) = 1;
                end
        end
    else
        TargetEventCode = find(strcmp(OutputActions{x}, OutputChannelNames));
        if ~isempty(TargetEventCode)
            Value = OutputActions{x+1};
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
            sma.OutputMatrix(CurrentState,TargetEventCode) = Value;
        else
            error(['Check spelling of your output actions for state: ' StateName '.']);
        end
    end
end

%% Add self timer
sma.StateTimers(CurrentState) = StateTimer;

%% Return state matrix
sma_out = sma;

%%%%%%%%%%%%%% End Main Code. Functions below. %%%%%%%%%%%%%%

function EventSpellingErrorMessage(ThisStateName)
error(['Check spelling of your state transition events for state: ' ThisStateName '. Valid events (% is an index): Port%In Port%Out BNC%High BNC%Low Wire%High Wire%Low SoftCode% GlobalTimer%End Tup'])

function [IsOp, opCode] = findOpName(ThisStateName)
IsOp = false; opCode = 0;
if ThisStateName(1) == '>'
    switch ThisStateName(2:end)
        case 'exit'
            IsOp = true;
            opCode = 65537;
        case 'back'
            IsOp = true;
            opCode = 65538;
    end
else
    if length(ThisStateName) == 4
        if strcmpi(ThisStateName,'exit') % Accept 'exit' without > for backwards compatability
            IsOp = true;
            opCode = 65537;
        end
    end
end