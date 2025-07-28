function protocolFilePath = findProtocolFile(protocolRootFolder, protocolPointer)
% Find the file path for the given protocol name in the given folder
% protocolFilePath = findProtocolFile(protocolRootFolder, protocolPointer)
%
% Arguments
% ---------
% protocolRootFolder : char
%     Path to the folder containing the protocols
% protocolPointer : char
%     Name of the protocol, which can have folder names to handle ambiguity
%       e.g. 'Group1/MyProtocol' or 'Protocols/Group1/MyProtocol'
%
% Returns
% -------
% protocolFilePath : char
%     Absolute path to the protocol file

% Normalize paths to avoid issues with different OS path separators
protocolPointer = strrep(protocolPointer, '/', filesep);
protocolPointer = strrep(protocolPointer, '\', filesep);

% Split the protocolPointer into parts based on file separators
pathParts = strsplit(protocolPointer, filesep);

% Extract the actual protocolName (last element)
protocolName = pathParts{end};

% Retrieve and match protocols
protocolStruct = BpodLib.path.findAllProtocols(protocolRootFolder);
matchedProtocols = protocolStruct(strcmp({protocolStruct.Name}, protocolName));


% Check the number of matches
numMatches = numel(matchedProtocols);
if numMatches == 1
    % If exactly one match, return the file path
    protocolFilePath = fullfile(matchedProtocols(1).Path, [protocolName, '.m']);
elseif numMatches > 1

    for depth = 1:length(pathParts)
        % Construct the trailing path from the last 'depth' elements of pathParts
        trailingPath = fullfile(pathParts{end-depth+1:end});
    
        % Filter matchedProtocols by checking if their paths end with trailingPath
        filteredProtocols = matchedProtocols(...
            cellfun(@(x) endsWith(x, trailingPath, 'IgnoreCase', true), {matchedProtocols.Path}));
    
        if numel(filteredProtocols) == 1
            protocolFilePath = fullfile(filteredProtocols(1).Path, [pathParts{end}, '.m']);
            return
        end
    end
    
    error('BpodLib:path:AmbiguousProtocolMatch', 'Multiple matches found for protocol %s', protocolName);
else
    error('BpodLib:path:ProtocolNotFound', 'Protocol file %s not found', protocolName);
end
