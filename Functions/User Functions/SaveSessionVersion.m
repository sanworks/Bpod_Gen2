function hashOut = SaveSessionVersion(varargin)
%SaveSessionVersion - Save current protocol files and their hashes into SessionData.Info.VersionControl.ProtocolFiles
%  SaveSessionVersion(___)
%  Using SaveSessionVersion within a protocol file will hash all files in the same directory as the protocol into SessionData.Info.VersionControl.ProtocolFiles.
%  Hashes are unique to the file contents, so they can be used to determine if the protocol has changed.
%  Hashes are computed using the MD5 algorithm and recorded as hexadecimal strings.
%  
%  Args:
%   excludedExtensions (cell): list of file extensions to exclude from hashing (default: {})
%   addtosessiondata (logical): whether to add the file hashes to the session data (default: true)
%   dozip (logical): whether to zip the protocol files (default: true)
%   filepaths (cell): list of filepaths to hash (default: [], finds all files)
%   protocolpath (char): path to the protocol (default: BpodSystem.Path.CurrentProtocol)
%   BpodSystem (struct): BpodSystem struct (default: global BpodSystem)
%   verbose (logical): whether to print verbose output (default: false)
%
%  Returns (optional):
%   fileHashes (struct): struct with fields name and hash (optional)

% Parse input
p = inputParser();
p.addParameter('excludedExtensions', {}, @iscell);
p.addParameter('addtosessiondata', true, @islogical);
p.addParameter('dozip', true, @islogical);
p.addParameter('filepaths', [], @iscell);
p.addParameter('protocolpath', [], @ischar);
p.addParameter('BpodSystem', []);  % allow overriding of BpodSystem for testing purposes
p.addParameter('verbose', false, @islogical);
p.parse(varargin{:});

% Prepare variables
if isempty(p.Results.BpodSystem)
    global BpodSystem
else
    BpodSystem = p.Results.BpodSystem;
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


% Hash files
fileHashes = struct();
fileindex = 0;
for i = 1:length(filepaths)
    if filepaths(i).isdir
        continue
    end
    [~, ~, ext] = fileparts(filepaths(i).name);
    if ismember(ext, p.Results.excludedExtensions)
        continue
    end
    fileindex = fileindex + 1;
    fileHashes(i).name = filepaths(i).name;
    fileHashes(i).folder = filepaths(i).folder;
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
    if ~isfield(BpodSystem.Data, 'Info')
        BpodSystem.Data.Info = struct();
    end
    if ~isfield(BpodSystem.Data.Info, 'VersionControl')
        BpodSystem.Data.Info.VersionControl = struct();
    end
    BpodSystem.Data.Info.VersionControl.ProtocolFiles = fileHashes;
end

% Zip files
if p.Results.dozip
    [savelocation, fname] = fileparts(BpodSystem.Path.CurrentDataFile);
    zipfilename = fullfile(savelocation, [fname, '_protocol_files.zip']);
    zip(zipfilename, fullfile(protocolpath, '*.*'));
    if p.Results.verbose
        fprintf('Zipped protocol files to %s\n', zipfilename);
    end

if nargout > 0
    hashOut = fileHashes;
end

end