function path = getPath(target)
switch lower(target)
    case 'assets'
        % Return path to the assets directory
        path = fullfile(fileparts(BpodTest.getPath('self')), 'assets');
    case 'self'
        % Return path to the current script
        path = fileparts(mfilename('fullpath'));
    otherwise
        error("Target '%s' not recognized.", target)
end