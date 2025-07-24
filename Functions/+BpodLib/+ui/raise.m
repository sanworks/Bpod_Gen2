function result = raise(UIObject)
% Focus/raise a figure object is possible.
% result = raise(UIObject)
%
% Arguments
% ---------
% UIObject : object
%     Object in BpodLib used to maintain a figure window
%
% Returns
% -------
% result : bool
%     Returns true if successful, false otherwise

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

result = false;
objFigure = UIObject.GUIHandles.Figure;

if ~isvalid(objFigure)
    return
end

figure(objFigure)
result = true;

end