function loadSubjects(BpodSystem, protocolName)
% Load all subjects in the data folder that have a folder for the given protocol

subjectNames = BpodLib.launcher.findSubjects(BpodSystem.Path.DataFolder, protocolName, BpodSystem.GUIData.DummySubjectString);

set(BpodSystem.GUIHandles.SubjectSelector,'String',subjectNames);
set(BpodSystem.GUIHandles.SubjectSelector,'Value',1);

end