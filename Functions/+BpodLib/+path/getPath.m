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
    comfolder = sprintf('Machine-%s', com);
end

switch lower(target)
    % protocol and data roots can be set by the user in the Bpod console
    case 'config'
        if isSingle
            path = fullfile(BpodLib.path.getPath(BpodSystem, 'local', varargin{:}), 'Config');
        else
            path = fullfile(BpodLib.path.getPath(BpodSystem, 'local', varargin{:}), 'Config', comfolder);
        end
    case 'local'
        path = BpodSystem.Path.LocalDir;
    case 'liquidcalibration'
%         legacyPath = fullfile(BpodLib.path.getPath(BpodSystem, 'settings', 'setup', 'single'), 'Calibration Files');
%         if isfile(fullfile(legacyPath, 'LiquidCalibration.mat'))
%             path = legacyPath;
%             return
%         end
        if BpodLib.path.compatibility.isLegacySettings(BpodLib.path.getPath(BpodSystem, 'local', varargin{:}))
            path = fullfile(BpodLib.path.getPath(BpodSystem, 'local'), 'Calibration Files');
            return
        end
        path = fullfile(BpodLib.path.getPath(BpodSystem, 'config', varargin{:}));
    case 'root'
        path = BpodSystem.Path.BpodRoot;
    case 'settings'
        LocalDir = BpodLib.path.getPath(BpodSystem, 'local', varargin{:});
        if BpodLib.path.compatibility.isLegacySettings(LocalDir)
            path = fullfile(LocalDir, 'Settings');
        else
            path = BpodLib.path.getPath(BpodSystem, 'config', varargin{:});
        end
    otherwise
        error('BpodLib:Path:UnrecognisedTarget', "Target '%s' not recognized.", target)
end