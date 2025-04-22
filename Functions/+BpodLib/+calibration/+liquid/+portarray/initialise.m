function initialise(BpodSystem)

if isempty(BpodSystem.CalibrationTables.PortArrays)
    error('BpodLib:PortArrayInitialise:ExistingData', 'PortArray data is already loaded in.')
else
    BpodSystem.CalibrationTables.PortArrays = BpodLib.calibration.liquid.portarray.createValveManager(BpodSystem);
end

BpodLib.calibration.liquid.portarray.launchCalibrator(BpodSystem)