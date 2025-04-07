function launchLiquidCalibrationUI(varargin)
% Launch a liquid calibration GUI
% This is called in BpodSettingsMenu and handles legacy contingencies.
p = inputParser();
p.addRequired('BpodSystem')
p.parse(varargin{:})

BpodSystem = p.Results.BpodSystem;

% Legacy system
if isa(BpodSystem.CalibrationTables.LiquidCal, 'struct')
    BpodLiquidCalibration('Calibrate');
    return
end

if isfield(BpodSystem.GUIHandles, 'LiquidCalibrator')
    if isfield(BpodSystem.GUIHandles.LiquidCalibrator.GUIHandles, 'MainFig') && ~verLessThan('MATLAB', '8.4')
        if isgraphics(BpodSystem.GUIHandles.LiquidCalibrator.GUIHandles.MainFig)
            figure(BpodSystem.GUIHandles.LiquidCalibrator.GUIHandles.MainFig);
            return;
        end
    end
end
BpodLib.calibration.liquid.LiquidCalibratorUI(BpodSystem.CalibrationTables.LiquidCal, 'BpodSystem', BpodSystem)

end