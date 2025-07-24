function datestring = isotime(varargin)
% Get the current date and/or time
% datestring = isotime(varargin)
%
% Arguments
% ---------
% format : char
%     Format of the output string, either 'datetime' (default), 'iso8601', 'date', or 'time'
%
% Returns
% -------
% datestring : datetime
%     Current time in format ready for char/JSON encoding/display

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

datestring = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');

if isempty(varargin)
    return
end

p = inputParser();
p.addOptional('format', 'datetime', @ischar);
p.parse(varargin{:});

switch lower(p.Results.format)
    case 'datetime'
        datestring = datetime(datestring, 'Format', 'yyyy-MM-dd HH:mm:ss');
    case 'iso8601'
        datestring = datetime(datestring, 'Format', 'yyyy-MM-ddTHH:mm:ss');
    case 'path'
        % This is used for filepathing, hardcoded into SaveBpodData
        datestring = datetime(datestring, 'Format', 'yyyyMMdd_HHmmss');
    case 'date'
        datestring = datetime(datestring, 'Format', 'yyyy-MM-dd');
    case 'time'
        datestring = datetime(datestring, 'Format', 'HH:mm:ss');
    otherwise
        error('BpodLib:Utils:Isotime:UnrecognisedFormat', "Format '%s' not recognised", p.Results.format)
end

end