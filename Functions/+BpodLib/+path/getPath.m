function path = getPath(target, varargin)
% Retrieve the path to something
% path = getPath(target, _)
%
% Examples
% --------
% path = getPath('liquidcalibration', BpodSystem, 'setuptype', 'single')
% path = getPath('config', 'LocalDir', LocalDirPath, 'setuptype', 'multi', 'com', 'COM3')
%
% Arguments
% ---------
% target : char
%     The target path to retrieve, can be one of the following:
%         - 'config': Path to the config folder
%         - 'local': Path to the local directory
%         - 'liquidcalibration': Path to the liquid calibration files
%         - 'root': Path to the Bpod root directory
%         - 'settings': Path to the settings folder
% BpodSystem : BpodObject or struct
%     Optional, if not provided you must specify 'LocalDir' keyword argument
%
% Keyword Argument
% ----------------
% setuptype : char
%     What kind of setup (single/multi) to find path for, defaults to auto-detecting
% LocalDir : char
%     The local directory to use, if not provided uses BpodSystem.Path.LocalDir. This overrides auto-detection of LocalDir from BpodSystem.
% com : char
%     The COM port to use for multi setups, if not provided uses BpodSystem.SerialPort.PortName
%
% Returns
% -------
% path : char
%     The path to the requested target

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

p = inputParser();
p.addOptional('BpodSystem', [], @(x) isempty(x) || isstruct(x) || isa(x, 'BpodObject') || isa(x, 'BpodLib.BpodObject.MockBpodObject'))
p.addParameter('setuptype', [], @(x) isempty(x) || ischar(x) || isstring(x))
p.addParameter('LocalDir', [], @(x) isempty(x) || ischar(x) || isstring(x))
p.addParameter('com', [], @(x) isempty(x) || ischar(x) || isstring(x))
p.parse(varargin{:})

BpodSystem = p.Results.BpodSystem;

if strcmp(target, 'root')
    path = fileparts(which('Bpod'));
    [~, parentDir] = fileparts(path);
    if strcmp(parentDir, 'Internal Functions')
        path = fileparts(fileparts(path)); % go up two levels if in Internal Functions
    end
    assert(isfolder(path), 'BpodLib:Path:RootNotFound', 'Bpod root directory not found. Ensure Bpod is installed correctly.');
    [~, parentDir] = fileparts(path);
    assert(strcmpi(parentDir, 'Bpod_Gen2'), 'BpodLib:Path:RootNotBpod', 'Bpod root directory is not named "Bpod_Gen2". Ensure Bpod is installed correctly.');
    return
end

assert(~isempty(p.Results.BpodSystem) || ~isempty(p.Results.LocalDir), 'BpodLib:Path:MissingPathReference', 'Either BpodSystem or LocalDir must be provided to getPath.')

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
    isSingle = ~BpodLib.multi.isMultiSetup(BpodSystem, 'LocalDir', p.Results.LocalDir); % this computer doesn't have multiple State Machines
end

if ~isSingle
    if ~isempty(p.Results.com)
        com = p.Results.com;
    else
        assert(~isempty(BpodSystem), "For multi setups 'com' or BpodSystem must be provided.");
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
        if BpodLib.path.compatibility.isLegacySettings(BpodLib.path.getPath('local', varargin{:}))
            path = fullfile(BpodLib.path.getPath('local', p.Results.BpodSystem), 'Calibration Files');
            return
        end
        path = fullfile(BpodLib.path.getPath('config', varargin{:}));
    % case 'root'
        % this is handled before anything else since it's fixed
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