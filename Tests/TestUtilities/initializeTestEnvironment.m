function testEnvironment = initializeTestEnvironment(rootPath)
% Create a directory structure for testing the findProtocolFile function
%
% Inputs
% ------
% rootPath : str
%     Path to the root directory where the test environment will be created
%
% Outputs
% -------
% testEnvironment : struct
%     Various properties specific to environment (e.g. .protocolFolder)
% The structure will be as follows:
% rootPath/
%     Bpod Local/
%         Data/
%             FakeSubject/
%                 Protocol_matching1/
%                     Session Data/
%                     Session Settings/
%                         DefaultSettings.mat
%                         settings1.mat
%                 Protocol_unique1/
%                 Protocol_unique2/
%             Subject1/
%                 Protocol_unique1/
%                 Protocol_matching1/
%             Subject2/
%                 Protocol_matching1/
%                 Protocol_unique2/
%         Protocols/
%             Procotol_unique1/Protocol_unique1.m
%             Protocol_unique2
%             Protocol_matching1
%             subfolderA/
%                 Protocol_matching1
%                 Protocol_matching2
%             subfolderB/
%                 subfolderC/
%                     Protocol_unique4
%                 Protocol_unique3
%                 Protocol_matching2

protocolFolder = fullfile(rootPath, 'Bpod Local/Protocols');
dataFolder = fullfile(rootPath, 'Bpod Local/Data');

% Create testEnvironment
testEnvironment = struct;
testEnvironment.protocolFolder = protocolFolder;
testEnvironment.dataFolder = dataFolder;

% Create a protocol folder structure
create_protocol(fullfile(protocolFolder), 'Protocol_unique1');
create_protocol(fullfile(protocolFolder), 'Protocol_unique2');
create_protocol(fullfile(protocolFolder), 'Protocol_matching1');
create_protocol(fullfile(protocolFolder, 'subfolderA'), 'Protocol_matching1');
create_protocol(fullfile(protocolFolder, 'subfolderA'), 'Protocol_matching2');
create_protocol(fullfile(protocolFolder, 'subfolderB'), 'Protocol_unique3');
create_protocol(fullfile(protocolFolder, 'subfolderB'), 'Protocol_matching2');
create_protocol(fullfile(protocolFolder, 'subfolderB/subfolderC'), 'Protocol_unique4');

% Create a data folder structure
create_datafolder(dataFolder, 'FakeSubject', 'Protocol_matching1');
create_datafolder(dataFolder, 'FakeSubject', 'Protocol_unique1');
create_datafolder(dataFolder, 'FakeSubject', 'Protocol_unique2');
create_datafolder(dataFolder, 'Subject1', 'Protocol_unique1');
create_datafolder(dataFolder, 'Subject1', 'Protocol_matching1');
create_datafolder(dataFolder, 'Subject2', 'Protocol_matching1');
create_datafolder(dataFolder, 'Subject2', 'Protocol_unique2');

% Create settings files
filepath = fullfile(dataFolder, 'FakeSubject', 'Protocol_matching1', 'Session Settings', 'DefaultSettings.mat');
emptystruct = struct;
save(filepath, 'emptystruct');
dummysettings = struct('dummy', 'dummy');
filepath = fullfile(dataFolder, 'FakeSubject', 'Protocol_matching1', 'Session Settings', 'settings1.mat');
save(filepath, 'dummysettings');

end

function create_protocol(folderPath, protocolName)
    % Create a folder with the protocol name and an empty protocol file
    mkdir(fullfile(folderPath, protocolName));
    fileID = fopen(fullfile(folderPath, protocolName, [protocolName '.m']), 'w');
    fprintf(fileID, 'function %s\n disp("This is a protocol file.");', protocolName);
    fclose(fileID);
end

function create_datafolder(dataFolder, subjectName, protocolName)
    % Create a data folder structure for a subject and protocol
    mkdir(fullfile(dataFolder, subjectName, protocolName, 'Session Data'));
    mkdir(fullfile(dataFolder, subjectName, protocolName, 'Session Settings'));
end
