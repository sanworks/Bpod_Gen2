function launchCalibrator(BpodSystem)
% Launch a liquid calibrator with the port array

savepath = fullfile(BpodLib.path.getPath('liquidcalibration', BpodSystem), 'LiquidCalibration-PortArrays.json');
if isempty(BpodSystem.CalibrationTables.PortArrays)
    error('BpodLib:portarraylaunchCalibrator:NoData', "No existing port array data found, did you mean BpodLib.calibration.liquid.portarray.initialize(BpodSystem) ?")
end
BpodLib.calibration.liquid.LiquidCalibratorUI(BpodSystem.CalibrationTables.PortArrays, 'BpodSystem', BpodSystem, 'savepath', savepath);