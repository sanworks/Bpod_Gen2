function formattedText = createMultiLine(cellText, varargin)
% Format multiline text destined for uicontrol objects
% formattedText = createMultiLine(cellText)
%
% Arguments
% ---------
% cellText : cell
%     Cell of chars/strings that you want to display in multiple lines
%
% Returns
% -------
% formattedText : char
%     Returns char appropriately

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

if verLessThan('matlab', '25')
    textFormat = repmat('%s<br>', 1, numel(cellText));
    textFormat = textFormat(1:end-4);  % remove trailing <br>
    cellText = sprintf(textFormat, cellText{:});

    formattedText = ['<html>' cellText '</html>'];
else
    textFormat = repmat('%s\n', 1, numel(cellText));
    textFormat = textFormat(1:end-2);

    formattedText = sprintf(textFormat, cellText{:});
end