function dataFilePath = createDataFilePath(dataFolder, protocolName, subjectName)
% Create a file path for the data file

dateInfo = datestr(now, 30);
dateInfo(dateInfo == 'T') = '_';
fileName = [subjectName '_' protocolName '_' dateInfo '.mat'];


dataFilePath = fullfile(dataFolder, subjectName, protocolName, 'Session Data', fileName);

end