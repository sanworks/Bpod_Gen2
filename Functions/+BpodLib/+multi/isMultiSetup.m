function result = isMultiSetup(BpodSystem)
% Determine if the system is being run on a computer with multiple state machines attached.

% Currently the only way to check is if multiple liquid calibration files exist.
filelist = dir(fullfile(BpodSystem.Path.LocalDir, 'Calibration Files'));
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

result = sum(validLogical) > 1;

end