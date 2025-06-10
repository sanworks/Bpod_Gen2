function path = getPath(target, varargin)
% Retrieve the path to something
% path = getPath(target, _)
%
% :param setuptype: What kind of setup (single/multi) to find path for, defaults to auto-detecting
% :type setuptype: char

p = inputParser();
p.addOptional('BpodSystem', [], @(x) isempty(x) || isstruct(x) || isa(x, 'BpodObject') || isa(x, 'BpodLib.BpodObject.MockBpodObject'))
p.addParameter('setuptype', [])
p.addParameter('LocalDir', [], @(x) isempty(x) || ischar(x) || isstring(x))
p.addParameter('com', [], @(x) isempty(x) || ischar(x) || isstring(x))
p.parse(varargin{:})

BpodSystem = p.Results.BpodSystem;

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
    if ~isempty(p.Results.com)
        com = p.Results.com;
    else
        assert(~isempty(BpodSystem), 'BpodSystem must be provided for multi setups');
        com = BpodLib.utils.getCurrentCOM(BpodSystem);
    end
    comfolder = sprintf('Machine-%s', com);
end

switch lower(target)
    % protocol and data roots can be set by the user in the Bpod console
    case 'config'
        if isSingle
            path = fullfile(BpodLib.path.getPath('local', varargin{:}), 'Config');
        else
            path = fullfile(BpodLib.path.getPath('local', varargin{:}), 'Config', comfolder);
        end
    case 'local'
        if ~isempty(p.Results.LocalDir)
            path = p.Results.LocalDir;
        else
            path = BpodSystem.Path.LocalDir;
        end
    case 'liquidcalibration'
%         legacyPath = fullfile(BpodLib.path.getPath('settings', 'setup', 'single'), 'Calibration Files');
%         if isfile(fullfile(legacyPath, 'LiquidCalibration.mat'))
%             path = legacyPath;
%             return
%         end
        if BpodLib.path.compatibility.isLegacySettings(BpodLib.path.getPath('local', varargin{:}))
            path = fullfile(BpodLib.path.getPath('local', p.Results.BpodSystem), 'Calibration Files');
            return
        end
        path = fullfile(BpodLib.path.getPath('config', varargin{:}));
    case 'root'
        path = BpodSystem.Path.BpodRoot;
    case 'settings'
        LocalDir = BpodLib.path.getPath('local', varargin{:});
        if BpodLib.path.compatibility.isLegacySettings(LocalDir)
            path = fullfile(LocalDir, 'Settings');
        else
            path = BpodLib.path.getPath('config', varargin{:});
        end
    otherwise
        error('BpodLib:Path:UnrecognisedTarget', "Target '%s' not recognized.", target)
end