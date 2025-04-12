function result = isMultiSetup(BpodSystem)
% Determine if the system is being run on a computer with multiple state machines attached.

% Currently the only way to check is if multiple liquid calibration files exist.
existingCalibrationFiles = BpodLib.calibration.liquid.multi.findCalibrationFiles(BpodSystem);

result = numel(existingCalibrationFiles) > 2;

end