function datestring = isotime(varargin)
% Get the current time in ISO format
% :param format: the format of the output string, either 'datetime' (default), 'iso8601', 'date', or 'time'
% :type format: char
% :return datestring: the current time in format ready for char/JSON encoding/display
% :rtype datestring: datetime
datestring = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');

if isempty(varargin)
    return
end

p = inputParser();
p.addOptional('format', 'datetime', @ischar);
p.parse(varargin{:});

switch lower(p.Results.format)
    case 'datetime'
        datestring = datetime(datestring, 'yyyy-MM-dd HH:mm:ss');
    case 'iso8601'
        datestring = datetime(datestring, 'yyyy-MM-ddTHH:mm:ss');
    case 'date'
        datestring = datetime(datestring, 'yyyy-MM-dd');
    case 'time'
        datestring = datetime(datestring, 'HH:mm:ss');
    otherwise
        error('BpodLib:Utils:Isotime:UnrecognisedFormat', "Format '%s' not recognised", p.Results.format)
end

end