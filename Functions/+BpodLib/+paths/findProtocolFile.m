function protocolFilePath = findProtocolFile(protocolFolder, fullProtocolName)
% protocolFilePath = findProtocolFile(protocolFolder, protocolName)
% Find the file path for the given protocol name in the given folder
% Inputs
% ------
% protocolFolder : str
%     Path to the folder containing the protocols
% fullProtocolName : str
%     Name of the protocol

% Normalize paths to avoid issues with different OS path separators
fullProtocolName = strrep(fullProtocolName, '/', filesep);
fullProtocolName = strrep(fullProtocolName, '\', filesep);

% Split the fullProtocolName into parts based on file separators
pathParts = strsplit(fullProtocolName, filesep);

% Extract the actual protocolName (last element)
protocolName = pathParts{end};

% Construct the subfolder path (if specified)
subfolderPath = fullfile(protocolFolder, pathParts(1:end-1));

% Retrieve and match protocols
protocolStruct = BpodLib.paths.findAllProtocols(protocolFolder);
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
            return;  % Exit the function if a unique match is found
        else
            continue
        end
    end
    
    error('BpodLib:AmbiguousMatch', 'Multiple matches found for protocol %s', protocolName);
else
    error('BpodLib:PathNotFound', 'Protocol file %s not found', protocolName);
end
