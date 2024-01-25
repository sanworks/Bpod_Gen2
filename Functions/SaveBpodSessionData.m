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

% SaveBpodSessionData() saves the BpodSystem.Data struct to the current data
% file. It overwrites the previous file.
% Note that SaveBpodSessionData can take time to execute, prolonging the
% inter-trial interval as the data file gets bigger if using RunStateMachine() 
% instead of BpodTrialManager(). To mitigate this issue, RunStateMachine users may 
% consider calling SaveBpodSessionData only a few times per session, or even 
% at the end (at risk of losing data in a crash)
%
% Arguments: None
% Returns: None
% Example usage: SaveBpodSessionData;

function SaveBpodSessionData

global BpodSystem % Import the global BpodSystem object

SessionData = BpodSystem.Data;
save(BpodSystem.Path.CurrentDataFile, 'SessionData');
