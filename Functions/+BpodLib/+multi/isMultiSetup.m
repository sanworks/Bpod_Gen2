function result = isMultiSetup(varargin)
%result = BpodLib.multi.isMultiSetup(BpodSystem, _)
% Determine if the system is being run on a computer with multiple state machines attached.
% BpodSystem is required to be passed in if 'LocalDir' is not specified.
%
% Examples
% --------
% result = BpodLib.multi.isMultiSetup(BpodSystem)
% result = BpodLib.multi.isMultiSetup('LocalDir', '/path/to/local/dir')

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