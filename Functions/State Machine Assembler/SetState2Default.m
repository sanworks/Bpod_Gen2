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

% SetState2Default() Sets a single state's state change conditions, output actions or both to defaults.
%
% Arguments:
% stateName: The name of the state to modify
% parameterName: The name of the parameter to modify. It can be ONE of the following:
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

function sma_out = SetState2Default(sma, stateName, parameterName)

global BpodSystem % Import the global BpodSystem object

% Verify target state name
targetStateNumber = find(strcmp(stateName,sma.StateNames));
if isempty(targetStateNumber)
    error(['Error: no state called "' stateName '" was found in the state matrix.'])
end

% Set the target field(s) of the state to default
switch parameterName
    case 'StateChangeConditions'
         sma.InputMatrix(targetStateNumber,:)= ones(1,BpodSystem.BlankStateMachine.meta.InputMatrixSize)*targetStateNumber;
    case 'OutputActions'
        sma.OutputMatrix(targetStateNumber,:) = zeros(1,BpodSystem.BlankStateMachine.meta.OutputMatrixSize);
    case 'All'
        sma.InputMatrix(targetStateNumber,:)= ones(1,BpodSystem.BlankStateMachine.meta.InputMatrixSize)*targetStateNumber;
        sma.OutputMatrix(targetStateNumber,:) = zeros(1,BpodSystem.BlankStateMachine.meta.OutputMatrixSize);
    otherwise
        error('ParameterName must be one of the following: ''StateChangeConditions'', ''OutputActions'', ''All''')
end
sma_out = sma;
