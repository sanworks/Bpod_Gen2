function createDefaultFile()
% Create the default LiquidCalibration.json file in Examples/

LiquidCal= BpodLib.calibration.liquid.compatibility.createDummyData();
rootPath = BpodLib.path.getPath('root');
filePath = fullfile(rootPath, 'Examples/Example Calibration Files/LiquidCalibration.json');

% Insert data
dateString = "2000-01-01T00:00:00";
saveData = LiquidCal.createSaveData();
saveData.metadata.modification_datetime = dateString;
saveData.metadata.COM = "example data";

if verLessThan('matlab', '9.10') % R2021a is 9.10
    writeData = jsonencode(saveData);
else
    writeData = jsonencode(saveData, 'PrettyPrint', true);
end
fid = fopen(filePath, 'w');
fwrite(fid, writeData, 'char');
fclose(fid);


end