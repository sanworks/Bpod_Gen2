function testEnvironment = createDummyProtocolFolders(rootPath)
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
%                         FakeSubject_Protocol_matching1_20160315_021512.mat
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
protocolStructure = {...
    {fullfile(protocolFolder), 'Protocol_unique1'}, ...
    {fullfile(protocolFolder), 'Protocol_unique2'}, ...
    {fullfile(protocolFolder), 'Protocol_matching1'}, ...
    {fullfile(protocolFolder, 'subfolderA'), 'Protocol_matching1'}, ...
    {fullfile(protocolFolder, 'subfolderA'), 'Protocol_matching2'}, ...
    {fullfile(protocolFolder, 'subfolderB'), 'Protocol_unique3'}, ...
    {fullfile(protocolFolder, 'subfolderB'), 'Protocol_matching2'}, ...
    {fullfile(protocolFolder, 'subfolderB/subfolderC'), 'Protocol_unique4'}, ...
    };
for i = 1:length(protocolStructure)
    BpodTest.dir.createProtocolMaterials(protocolStructure{i}{1}, protocolStructure{i}{2}, 'dataFolder', false);
end

dataStructure = {...
    {'FakeSubject', 'Protocol_matching1'}, ...
    {'FakeSubject', 'Protocol_unique1'}, ...
    {'FakeSubject', 'Protocol_unique2'}, ...
    {'Subject1', 'Protocol_unique1'}, ...
    {'Subject1', 'Protocol_matching1'}, ...
    {'Subject2', 'Protocol_matching1'}, ...
    {'Subject2', 'Protocol_unique2'}, ...
    };

for i = 1:length(dataStructure)
    BpodTest.dir.createDataFolder(dataFolder, dataStructure{i}{1}, dataStructure{i}{2});
end

% Create settings files
filepath = fullfile(dataFolder, 'FakeSubject', 'Protocol_matching1', 'Session Settings', 'DefaultSettings.mat');
emptystruct = struct;
save(filepath, 'emptystruct');
dummysettings = struct('dummy', 'dummy');
filepath = fullfile(dataFolder, 'FakeSubject', 'Protocol_matching1', 'Session Settings', 'settings1.mat');
save(filepath, 'dummysettings');

% Create dummy data files
filepath = fullfile(dataFolder, 'FakeSubject', 'Protocol_matching1', 'Session Data', 'FakeSubject_Protocol_matching1_20160315_021512.mat');
save(filepath, 'emptystruct');

end