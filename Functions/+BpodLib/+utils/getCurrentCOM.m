function comport = getCurrentCOM(BpodSystem)
% Return the name of the current COM
% comport = getCurrentCOM(BpodSystem)
%
% Will return 'EMU' if emulator mode, otherwise 'COMX'
% Linux dev/ttyUSB is converted to COM
%
% Arguments
% ---------
% BpodSystem : BpodObject
%
% Returns
% -------
% comport : char
%     'COMX' or 'EMU'

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

if ~isprop(BpodSystem, 'SerialPort') || isempty(BpodSystem.SerialPort)
    comport = 'EMU';
else
    comport = BpodSystem.SerialPort.PortName;
    % check if linux
    if isunix && ~ispc
        % convert to windows style
        comport = strrep(comport, 'dev/ttyUSB', 'COM');
    end
end

end