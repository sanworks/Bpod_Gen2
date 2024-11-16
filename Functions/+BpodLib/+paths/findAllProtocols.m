function protocolStruct = findAllProtocols(topProtocolFolderPath, depth)
% Find all protocols in the Bpod system
% protocolStruct = findAllProtocols()
% Inputs
% ------
% topProtocolFolderPath : str
%     Path to the top level protocol folder
% depth : int
%     Depth of recursion
% protocolStruct is a struct array with fields:
%   - Name: Name of the protocol
%   - Path: Path to the protocol

currentFolder = topProtocolFolderPath; % Top level protocol folder
if nargin < 2
    depth = Inf;
end

folderInfo = dir(currentFolder); % Get info about entries in the folder
folderInfo = folderInfo([folderInfo.isdir]); % Keep only directories
folderNames = {folderInfo.name}; % Get names of the directories
folderNames = folderNames(~cellfun(@(x) x(1) == '.', folderNames)); % Remove hidden folders

protocolStruct = struct; % Initialize empty list to hold protocol folders
iProtocol = 0;
for i = 1:length(folderNames)
    subfolderPath = fullfile(currentFolder, folderNames{i});

    % Check if there is an M-file with the same name as the folder
    if exist(fullfile(subfolderPath, [folderNames{i} '.m']), 'file')
        % Congrats its a protocol folder
        iProtocol = iProtocol + 1;
        protocolStruct(iProtocol).Name = folderNames{i}; % Add to list of protocol names
        protocolStruct(iProtocol).Path = subfolderPath; % Add to list of protocol folders
    elseif depth > 1
        % Recursively search for folders meeting criteria with reduced depth
        returnStruct = BpodLib.paths.findAllProtocols(subfolderPath, depth - 1);
        if ~isempty(fieldnames(returnStruct))
            protocolStruct = [protocolStruct, returnStruct];
        end
    end
end