function initializeTestEnvironment(rootPath)
% Create a directory structure for testing the findProtocolFile function
% Inputs
% ------
% rootPath : str
%     Path to the root directory where the test environment will be created
% 
% The structure will be as follows:
% rootPath/
%     Bpod Local/
%         Protocols/
%             Procotol_unique1/Protocol_unique1.m
%             Protocol_unique2
%             Protocol_matching1
%             subfolderA/
%                 Protocol_matching1
%                 Protocol_matching2
%             subfolderB/
%                 Protocol_unique3
%                 Protocol_matching2

protocolFolder = fullfile(rootPath, 'Bpod Local/Protocols');

% Create a protocol folder structure
create_protocol(fullfile(protocolFolder), 'Protocol_unique1');
create_protocol(fullfile(protocolFolder), 'Protocol_unique2');
create_protocol(fullfile(protocolFolder), 'Protocol_matching1');
create_protocol(fullfile(protocolFolder, 'subfolderA'), 'Protocol_matching1');
create_protocol(fullfile(protocolFolder, 'subfolderA'), 'Protocol_matching2');
create_protocol(fullfile(protocolFolder, 'subfolderB'), 'Protocol_unique3');
create_protocol(fullfile(protocolFolder, 'subfolderB'), 'Protocol_matching2');

end

function create_protocol(folderPath, protocolName)
    % Create a folder with the protocol name and an empty protocol file
    mkdir(fullfile(folderPath, protocolName));
    fileID = fopen(fullfile(folderPath, protocolName, [protocolName '.m']), 'w');
    fprintf(fileID, 'function %s\n disp("This is a protocol file.");', protocolName);
    fclose(fileID);
end