function result = isMultiSetup(BpodSystem, varargin)
% Determine if the system is being run on a computer with multiple state machines attached.

p = inputParser();
p.addParameter('LocalDir', '')
p.parse(varargin{:})
if isempty(p.Results.LocalDir)
    localDir = BpodSystem.Path.LocalDir;
else
    localDir = p.Results.LocalDir;
end

% Currently the only way to check is if multiple liquid calibration files exist.
filelist = dir(fullfile(localDir));
validLogical = false(numel(filelist), 1);
for idx = 1:numel(filelist)
    if ~filelist(idx).isdir
        continue
    end
    if numel(filelist(idx).name) < 12
        continue
    end
    validLogical(idx) = strcmp(filelist(idx).name(1:11), 'Machine-COM');
end

result = any(validLogical);

end