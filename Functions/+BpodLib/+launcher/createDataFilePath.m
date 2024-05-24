function dataFilePath = createDataFilePath(dataFolder, protocolName, subjectName)
% Create a file path for the data file to be saved
%
% Inputs
% ------
% dataFolder : char
%     The path to the data folder (e.g. Local Data/Data/)
% protocolName : char
%     The name of the protocol
% subjectName : char
%     The name of the subject

dateInfo = datestr(now, 30);
dateInfo(dateInfo == 'T') = '_';
fileName = [subjectName '_' protocolName '_' dateInfo '.mat'];


dataFilePath = fullfile(dataFolder, subjectName, protocolName, 'Session Data', fileName);

end