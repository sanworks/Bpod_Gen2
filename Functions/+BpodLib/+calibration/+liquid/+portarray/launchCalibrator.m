function launchCalibrator(BpodSystem)
% Launch a liquid calibrator with the port array

savepath = fullfile(BpodLib.path.getPath(BpodSystem, 'liquidcalibration'), 'LiquidCalibration-PortArrays.json');
BpodLib.calibration.liquid.LiquidCalibratorUI(BpodSystem.CalibrationTables.PortArrays, 'BpodSystem', BpodSystem, 'savepath', savepath)