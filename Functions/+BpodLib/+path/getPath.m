function path = getPath(BpodSystem, target, varargin)
% Retrieve the path to something
% path = getPath(BpodSystem, target)
%
% :param setuptype: What kind of setup (single/multi) to find path for, defaults to auto-detecting
% :type setuptype: char

p = inputParser();
p.addParameter('setuptype', [])
p.parse(varargin{:})

if ~isempty(p.Results.setuptype)
    switch p.Results.setuptype
        case 'single'
            isSingle = true;
        case 'multi'
            isSingle = false;
        otherwise
            error('BpodLib:Path:UnrecognisedSetupType', "setuptype must be either 'single' or 'multi'")
    end
else
    isSingle = ~BpodLib.multi.isMultiSetup(BpodSystem); % this computer doesn't have multiple State Machines
end

if ~isSingle
    com = BpodLib.utils.getCurrentCOM(BpodSystem);

    % check if linux
    if isunix && ~ispc
        % convert to windows style
        com = strrep(com, 'dev/ttyUSB', 'COM');
    end
end

switch lower(target)
    % protocol and data roots can be set by the user in the Bpod console
    case 'local'
        path = BpodSystem.Path.LocalDir;
    case 'liquidcalibration'
        path = BpodLib.path.getPath(BpodSystem, 'local');
        if isSingle
            path = fullfile(path, 'Calibration Files');
        else
            comfolder = sprintf('Machine-%s', com);
            path = fullfile(path, 'Calibration Files', comfolder);
        end
    case 'root'
        path = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
        if ~strcmp(path, BpodSystem.Path.BpodRoot)
            warning('BpodLib:Path:RootMismatch', 'The path to the BpodLib root folder does not match the path in BpodSystem. This may cause issues.')
        end
    otherwise
        error('BpodLib:Path:UnrecognisedTarget', "Target '%s' not recognized.", target)
end