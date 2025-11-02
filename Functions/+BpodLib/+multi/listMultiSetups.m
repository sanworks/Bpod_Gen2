function setupList = listMultiSetups(configDir)
% List all multi setups available.
% setupList = listMultiSetups(configDir)
%
% Arguments
% ---------
% configDir : char
%     Path to the Config/ directory containing multi setup folders (or not).
%
% Returns
% -------
% setupList : cell array of char
%     List of multi setup names found in the configDir. Is empty if no multi setups are found.

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

filelist = dir(fullfile(configDir, 'Machine-*'));

setupList = strcat({filelist.name}');

end