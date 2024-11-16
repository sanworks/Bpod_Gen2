function setDataFilePath(BpodSystem, protocolName, subjectName)

dataFolder = BpodSystem.Path.DataFolder;
dataFilePath = BpodLib.launcher.createDataFilePath(dataFolder, protocolName, subjectName);
localDir = dataFolder(max(find(dataFolder(1:end-1) == filesep)+1):end);
[~, fileName, ext] = fileparts(dataFilePath);
fileName = [fileName ext];

BpodSystem.Path.CurrentDataFile = dataFilePath;

set(BpodSystem.GUIHandles.DataFilePathDisplay, 'String',... 
    [filesep fullfile(localDir, subjectName, protocolName, 'Session Data') filesep],'interpreter','none');
set(BpodSystem.GUIHandles.DataFileDisplay, 'String', fileName);
end