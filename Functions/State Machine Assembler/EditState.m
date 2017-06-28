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

switch ParameterName
    case 'Timer'
        if ischar(ParameterValue)
            error('State timer durations must be numbers, in seconds')
        end
        if ParameterValue < 0
            error('When setting state timers, time (in seconds) must be positive.')
        end
        if ParameterValue > 3600
            error('State timers can not exceed 1 hour');
        end
        sma.StateTimers(TargetStateNumber) = ParameterValue;
    case 'StateChangeConditions'
        if ~iscell(ParameterValue)
            error('Incorrect format for state change conditions - must be a cell array of strings. Example: {''Port2Out'', ''WaitForResponse'', ''Tup'', ''ITI''}')
        end
        nConditions = length(ParameterValue);
        for x = 1:2:nConditions
            EventNames = BpodSystem.StateMachineInfo.EventNames;
            CandidateEvent = ParameterValue{x};
            CandidateEventCode = find(strcmp(CandidateEvent,EventNames));
            RedirectedStateNumber = find(strcmp(ParameterValue{x+1},sma.StateNames));
            if isempty(RedirectedStateNumber)
                error(['Error: the state "' ParameterValue{x+1} '" does not exist in the matrix you tried to edit.'])
            end
            if isempty(CandidateEventCode)
                CandidateEventName = CandidateEvent;
                if length(CandidateEventName > 4)
                    if sum(CandidateEventName(length(CandidateEventName)-3:length(CandidateEventName)) == '_End') == 4
                        % This is a transition for a global timer. Add to global timer matrix.
                        GlobalTimerNumber = str2double(CandidateEventName(length(CandidateEventName) - 4));
                        if ~isnan(GlobalTimerNumber)
                            sma.GlobalTimerMatrix(TargetStateNumber, GlobalTimerNumber) = RedirectedStateNumber;
                        else
                            EventSpellingErrorMessage(StateName);
                        end
                    else
                        EventSpellingErrorMessage(StateName);
                    end
                else
                    EventSpellingErrorMessage(StateName);
                end
            else
                sma.InputMatrix(TargetStateNumber,CandidateEventCode) = RedirectedStateNumber;
            end
        end
    case 'OutputActions'
        if ~iscell(ParameterValue)
            error('Incorrect format for output actions - must be a cell array of strings. Example: {''LEDState'', ''1'', ''ValveState'', ''3''}')
        end
        OutputActionNames = BpodSystem.StateMachineInfo.OutputChannelNames;
        for x = 1:2:length(ParameterValue)
            EventCode = find(strcmp(ParameterValue{x}, OutputActionNames));
            if ~isempty(EventCode)
                Value = ParameterValue{x+1};
                sma.OutputMatrix(TargetStateNumber,EventCode) = Value;
            else
                error(['Check spelling of your output actions for state: ' sma.StateNames{x} '.']);
            end
        end
    otherwise
        error('ParameterName must be one of the following: ''Timer'', ''StateChangeConditions'', ''OutputActions''')
end
sma_out = sma;
%%%%%%%%%%%%%% End Main Code. Functions below. %%%%%%%%%%%%%%
    
function EventSpellingErrorMessage(ThisStateName)
        error(['Check spelling of your state transition events for state: ' ThisStateName '. Valid events (% is an index): Port%In Port%Out BNC%High BNC%Low Wire%High Wire%Low SoftCode% GlobalTimer%End Tup'])