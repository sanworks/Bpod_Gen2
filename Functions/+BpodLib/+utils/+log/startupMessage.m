function message = startupMessage()
% Displays a startup message when Bpod is initialized.
% message = startupMessage()

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

message = sprintf('** Starting Bpod Console v%s **\nInitialized: %s', BpodSoftwareVersion_Semantic, BpodLib.utils.isotime());
% todo: add datetime and git head 