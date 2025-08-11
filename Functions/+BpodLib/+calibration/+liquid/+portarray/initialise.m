function initialise(BpodSystem)
% Initialise a new port array calibration configuration
% initialise(BpodSystem)
%
% Arguments
% ---------
% BpodSystem : BpodObject

% docstring
% signature
%
% Arguments
% ---------
% myarg : int
%     Descriptor
%
% Keyword Arguments
% -----------------
% verbose : logical (default=true)
%     Whether to display messages in Command Window.
%
% Returns
% -------
% completed : int
%     Returns 1 if successful, 0 otherwise

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

if isempty(BpodSystem.CalibrationTables.PortArrays)
    BpodSystem.CalibrationTables.PortArrays = BpodLib.calibration.liquid.portarray.createValveManager(BpodSystem);
else
    error('BpodLib:PortArrayInitialise:ExistingData', 'PortArray data is already loaded in, maybe you want BpodLib.calibration.liquid.portarray.launchCalibrator(BpodSystem)')
end