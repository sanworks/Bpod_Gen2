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
if strcmpi(StateName, 'exit')
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
sma.InputMatrix(CurrentState,:) = ones(1,nInputColumns)*CurrentState;
sma.OutputMatrix(CurrentState,:) = zeros(1,BpodSystem.StateMachineInfo.nOutputChannels);
sma.GlobalTimerStartMatrix(CurrentState,:) = ones(1,BpodSystem.HW.n.GlobalTimers)*CurrentState;
sma.GlobalTimerEndMatrix(CurrentState,:) = ones(1,BpodSystem.HW.n.GlobalTimers)*CurrentState;
sma.GlobalCounterMatrix(CurrentState,:) = ones(1,BpodSystem.HW.n.GlobalCounters)*CurrentState;
sma.ConditionMatrix(CurrentState,:) = ones(1,BpodSystem.HW.n.Conditions)*CurrentState;
sma.StateTimerMatrix(CurrentState) = CurrentState;
sma.StateTimers(CurrentState) = StateTimer;
sma.StatesDefined(CurrentState) = 1;

%% Make sure all the states in "StateChangeConditions" exist, and if not, create them as undefined states.
for x = 2:2:length(StateChangeConditions)
    ThisStateName = StateChangeConditions{x};
    if ~strcmpi(ThisStateName,'exit')
        isThere = sum(strcmp(ThisStateName, sma.StateNames)) > 0;
        if isThere == 0
            NewStateNumber = length(sma.StateNames)+1;
            sma.StateNames(NewStateNumber) = StateChangeConditions(x);
            sma.StatesDefined(NewStateNumber) = 0;
        end
    end
end
%% Add state transitions
EventNames = BpodSystem.StateMachineInfo.EventNames;
for x = 1:2:length(StateChangeConditions)
    CandidateEventCode = find(strcmp(StateChangeConditions{x},EventNames));
    TargetState = StateChangeConditions{x+1};
    if strcmpi(TargetState, 'exit')
        TargetStateNumber = NaN;
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
                            GlobalTimerNumber = str2double(CandidateEventName(length(CandidateEventName) - 4));
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
                        GlobalTimerNumber = str2double(CandidateEventName(length(CandidateEventName) - 6));
                        if ~isnan(GlobalTimerNumber)
                            sma.GlobalTimerStartMatrix(CurrentState, GlobalTimerNumber) = TargetStateNumber;
                        else
                            EventSpellingErrorMessage(ThisStateName);
                        end
                    otherwise
                        % This is a transition for a condition. Add to condition matrix
                    ConditionNumber = str2double(CandidateEventName(length(CandidateEventName)));
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
MetaActions = {'Valve', 'LED', 'LEDState', 'BNCState', 'WireState'}; % Valve is an alternate syntax for "ValveState", specifying one valve to open (1-8)
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
                Value = 2^(Value-1);
                sma.OutputMatrix(CurrentState,BpodSystem.HW.Pos.Output_SPI) = Value;
            case 2
                sma.OutputMatrix(CurrentState,BpodSystem.HW.Pos.Output_PWM+Value-1) = 255;
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
        end
    else
        TargetEventCode = find(strcmp(OutputActions{x}, OutputChannelNames));
        if ~isempty(TargetEventCode)
            Value = OutputActions{x+1};
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