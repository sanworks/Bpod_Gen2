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

% NewStateMachine() returns a blank state machine description that can be
% passed to AddState().

function sma = NewStateMachine

global BpodSystem % Import the global BpodSystem object

if isempty(BpodSystem)
    error('You must run Bpod() before assembling a state machine.')
end
sma = BpodSystem.BlankStateMachine;