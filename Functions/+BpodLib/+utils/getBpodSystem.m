function BpodSystem = getBpodSystem(parsedinputs)
% Retrieve BpodSystem from an input parser
% This function allows custom BpodSystems to be passed by argument
% 
% Arguments
% ---------
% parsedinputs : inputParser
%     An inputParser that has BpodSystem as an argument
%
% Returns
% ------
% BpodSystem : BpodObject
%     The object

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

results = parsedinputs.Results;

if isfield(results, 'BpodSystem')
    if isempty(results.BpodSystem)
        global BpodSystem
    else
        BpodSystem = results.BpodSystem;
    end
else
    global BpodSystem
end
if isempty(BpodSystem)
    error('BpodLib:getBpodSystem:EmptySystem', "BpodSystem is empty, this is likely because it has been used incorrectly.")
end
end