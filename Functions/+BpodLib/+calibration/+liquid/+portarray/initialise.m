function initialise(BpodSystem)

if isempty(BpodSystem.CalibrationTables.PortArrays)
    BpodSystem.CalibrationTables.PortArrays = BpodLib.calibration.liquid.portarray.createValveManager(BpodSystem);
else
    error('BpodLib:PortArrayInitialise:ExistingData', 'PortArray data is already loaded in, maybe you want BpodLib.calibration.liquid.portarray.launchCalibrator(BpodSystem)')
end

BpodLib.calibration.liquid.portarray.launchCalibrator(BpodSystem)