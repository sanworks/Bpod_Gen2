function result = isMultiSetup(varargin)
% Determine if the system is being run on a computer with multiple state machines attached.
% result = BpodLib.multi.isMultiSetup(BpodSystem, _)
%
% Arguments
% ---------
% BpodSystem : BpodObject
%     Optional, but is required to be passed in if 'LocalDir' is not specified.
%
% Keyword Arguments
% -----------------
% LocalDir : char
%     Location of Bpod Local/
%
% Examples
% --------
% result = BpodLib.multi.isMultiSetup(BpodSystem)
% result = BpodLib.multi.isMultiSetup('LocalDir', '/path/to/local/dir')

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
p.addOptional('BpodSystem', [], @(x) isempty(x) | isstruct(x) | isa(x, 'BpodObject') | isa(x, 'BpodLib.BpodObject.MockBpodObject'))
p.addParameter('LocalDir', '')
p.parse(varargin{:})
if ~isempty(p.Results.LocalDir)
    localDir = p.Results.LocalDir;
    SettingsDir = fullfile(localDir, 'Config');
else
    assert(~isempty(p.Results.BpodSystem), 'BpodLib:MultiSetup:NoBpodSystem', 'BpodSystem or LocalDir must be specified.');
    localDir = p.Results.BpodSystem.Path.LocalDir;
    SettingsDir = fullfile(localDir, 'Config');
end

% Currently the only way to check is if multiple liquid calibration files exist.
filelist = dir(fullfile(SettingsDir));
validLogical = false(numel(filelist), 1);
for idx = 1:numel(filelist)
    if ~filelist(idx).isdir
        continue
    end
    if numel(filelist(idx).name) < 11
        continue
    end
    validLogical(idx) = ismember(filelist(idx).name(1:11), {'Machine-COM', 'Machine-EMU'});
end

result = any(validLogical);

end