function subjectNames = findSubjects(dataFolder, protocolName, dummySubjectString)
% Find all subjects in the data folder that have a folder for the given protocol

candidateSubjects = dir(dataFolder);
subjectNames = cell(1);
nSubjects = 1;
subjectNames{1} = dummySubjectString;
for x = 1:length(candidateSubjects)
    if x > 2
        if candidateSubjects(x).isdir
            if ~strcmp(candidateSubjects(x).name, dummySubjectString)
                testpath = fullfile(dataFolder,candidateSubjects(x).name,protocolName);
                if exist(testpath) == 7
                    nSubjects = nSubjects + 1;
                    subjectNames{nSubjects} = candidateSubjects(x).name;
                end
            end
        end
    end
end
end