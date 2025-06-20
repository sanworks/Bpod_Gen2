function valveManager = convertFormat(LiquidCal)
% Convert LiquidCal structure to ValveDataManagerClass
%
% :param LiquidCal: the LiquidCalibration structure
% :type LiquidCal: struct
% :return: the ValveDataManager object
% :rtype: BpodLib.calibration.liquid.ValveDataManagerClass

% Create data object and add measurements
valveManager = BpodLib.calibration.liquid.ValveDataManagerClass();
nValves = numel(LiquidCal);
for valveNumber = 1:nValves
    % Original data stores valves in nonscalar structure
    valveName = sprintf('Valve%i', valveNumber);
    valveData = valveManager.createValve(valveName);
    originalData = LiquidCal(valveNumber);
    nMeasurements = size(originalData.Table, 1);
    for measurementIdx = 1:nMeasurements
        valveData.addMeasurement(originalData.Table(measurementIdx, 1), originalData.Table(measurementIdx, 2));
    end

    % Maintain original calibration datetime
    modifydatetime = datetime(originalData.LastDateModified, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd HH:mm:ss');
    valveData.LastDateModified = char(modifydatetime);
end

end