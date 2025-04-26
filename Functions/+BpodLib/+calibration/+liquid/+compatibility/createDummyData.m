function data = createDummyData()
% Create dummy default data for the liquid calibration
% :return data: the ValveDataManager object with the dummy data
% :rtype data: BpodLib.calibration.liquid.ValveDataManagerClass

% This function recreates the data originally shipped with Bpod_Gen2

data = BpodLib.calibration.liquid.ValveDataManagerClass();

% Create valvenames 'Valve1' to 'Valve8'
for i = 1:8
    valveName = sprintf('Valve%d', i);
    data.createValve(valveName);
end

% Add some dummy measurements
valve1 = data.getValve('Valve1');
valve1.addMeasurement(22, 2);
valve1.addMeasurement(66, 9.5);
valve1.addMeasurement(44, 5);
valve1.addMeasurement(57, 7.5);
valve1.addMeasurement(34, 3.5);

valve3 = data.getValve('Valve3');
valve3.addMeasurement(22, 1.5);
valve3.addMeasurement(46, 5.5);
valve3.addMeasurement(59, 7.5);
valve3.addMeasurement(35, 3.5);
valve3.addMeasurement(66, 8.5);

% Update LastDateModified to reflect the dummy data
valve1.LastDateModified = char(datetime('2016-11-17 16:08:26'));  % original from Bpod_Gen2
% valve3.LastDateModified = char(datetime('2024-07-17 09:22:28'));  % the date of this function's creation
valve3.LastDateModified = "";

end