function hashOut = SaveSessionVersion(varargin)
%SaveSessionVersion - Save current protocol files and their hashes into SessionData.Info.FileHashes
%  SaveSessionVersion(___)
%  Using SaveSessionVersion within a protocol file will hash all files in the same directory as the protocol.
%  Hashes are unique to the file contents, so they can be used to determine if the protocol has changed.
%  Hashes are computed using the MD5 algorithm and recorded as hexadecimal strings.
%  
%  Args:
%   addtosessiondata (logical): whether to add the file hashes to the session data (default: true)
%   BpodSystem (struct): BpodSystem struct (default: global BpodSystem)
%   filepaths (cell): list of filepaths to hash (default: [])
%   protocolpath (char): path to the protocol (default: BpodSystem.Path.CurrentProtocol)
%   verbose (logical): whether to print verbose output (default: false)
%
%  Returns (optional):
%   fileHashes (struct): struct with fields name and hash (optional)

% Parse input
p = inputParser();
p.addParameter('addtosessiondata', true, @islogical);
p.addParameter('BpodSystem', []);  % allow overriding of BpodSystem for 
p.addParameter('filepaths', [], @iscell);
p.addParameter('protocolpath', [], @ischar);
p.addParameter('verbose', false, @islogical);
p.parse(varargin{:});

% Prepare variables
if isempty(p.Results.BpodSystem)
    global BpodSystem
end

if isempty(p.Results.protocolpath)
    protocolpath = BpodSystem.Path.CurrentProtocol;
else
    protocolpath = p.Results.protocolpath;
    assert(isempty(p.Results.filepaths), 'Cannot specify both protocolpath and filepaths');
end

if isfile(protocolpath)
    protocolpath = fileparts(protocolpath);
end

% Determine which files to hash
if isempty(p.Results.filepaths)
    if p.Results.verbose
        fprintf('Looking for protocol files in %s\n', BpodSystem.Path.CurrentProtocol);
    end
    filepaths = dir(fullfile(protocolpath, '*.*'));  % look at top folders
    % remove dots
    filepaths = filepaths(~ismember({filepaths.name}, {'.', '..'}));
else
    filepaths = p.Results.filepaths;
end
% Print list of filenames concatenated
if p.Results.verbose
    fprintf('Found %d files in %s:\n\t', length(filepaths), protocolpath);
end


excludedExtensions = {};  % todo: allow users to specify exclusions

% Hash files
fileHashes = struct();
fileindex = 0;
for i = 1:length(filepaths)
    if filepaths(i).isdir
        continue
    end
    [~, ~, ext] = fileparts(filepaths(i).name);
    if ismember(ext, excludedExtensions)
        continue
    end
    fileindex = fileindex + 1;
    fileHashes(i).name = filepaths(i).name;
    fileHashes(i).hash = BpodLib.dataio.HashFile(fullfile(protocolpath, filepaths(i).name));
    if p.Results.verbose
        fprintf('%s, ', filepaths(i).name);
    end
end
if p.Results.verbose
    fprintf('\b\b\n');
    fprintf('Hashed %d files\n', fileindex);
end

if p.Results.addtosessiondata
    BpodSystem.Data.Info.FileHashes = fileHashes;
end

if nargout > 0
    hashOut = fileHashes;
end

end