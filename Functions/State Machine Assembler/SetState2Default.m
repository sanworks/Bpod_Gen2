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
function sma_out = SetState2Default(sma, StateName, ParameterName)
% Sets a single state's state change conditions, output actions or both to defaults.
%
% ParameterName can be ONE of the following:
% 1. 'StateChangeConditions'
% 2. 'OutputActions'
% 3. 'All'
%
% Examples:
%  This example sets all state change conditions for the "WaitForResponse" state to the same state (i.e. do nothing for all events):
%  sma = SetState2Default(sma, 'WaitForResponse', 'StateChangeConditions');
%
%  This example sets all events in the state Deliver_Stimulus to do nothing, AND sets OutputActions to {} (i.e. no output actions);
%  sma = SetState2Default(sma, 'Deliver_Stimulus', 'All');
%
global BpodSystem
TargetStateNumber = find(strcmp(StateName,sma.StateNames));
if isempty(TargetStateNumber)
    error(['Error: no state called "' StateName '" was found in the state matrix.'])
end

switch ParameterName
    case 'StateChangeConditions'
         sma.InputMatrix(TargetStateNumber,:)= ones(1,BpodSystem.BlankStateMachine.meta.InputMatrixSize)*TargetStateNumber;
    case 'OutputActions'
        sma.OutputMatrix(TargetStateNumber,:) = zeros(1,BpodSystem.BlankStateMachine.meta.OutputMatrixSize);
    case 'All'
        sma.InputMatrix(TargetStateNumber,:)= ones(1,BpodSystem.BlankStateMachine.meta.InputMatrixSize)*TargetStateNumber;
        sma.OutputMatrix(TargetStateNumber,:) = zeros(1,BpodSystem.BlankStateMachine.meta.OutputMatrixSize);
    otherwise
        error('ParameterName must be one of the following: ''StateChangeConditions'', ''OutputActions'', ''All''')
end
sma_out = sma;
