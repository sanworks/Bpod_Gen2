function matchingCOM = checkCOM(BpodSystem)
%matchingCOM = checkCOM(BpodSystem)
% Check if the COM port in the calibration file matches the current BpodSystem COM port.

matchingCOM = 'unknown';
BpodSystemCOM = BpodLib.utils.getCurrentCOM(BpodSystem);
LiquidCal = BpodSystem.CalibrationTables.LiquidCal;

if isempty(LiquidCal)
    % LiquidCal failed to load for some reason
    return
end

if isa(LiquidCal, 'struct')
    % Is a legacy system, no ability to check COM
    return
end

if ~isfield(LiquidCal.metadata, 'COM')
    return
end

if strcmp(LiquidCal.metadata.COM, BpodSystemCOM)
    matchingCOM = 'yes';
else
    matchingCOM = 'no';
end

end