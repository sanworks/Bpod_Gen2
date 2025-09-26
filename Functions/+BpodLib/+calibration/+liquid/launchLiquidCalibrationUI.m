function launchLiquidCalibrationUI(varargin)
% Launch a liquid calibration GUI
% This is called in BpodSettingsMenu and handles legacy contingencies.
p = inputParser();
p.addRequired('BpodSystem')
p.parse(varargin{:})

BpodSystem = p.Results.BpodSystem;
% Legacy system
if isa(BpodSystem.CalibrationTables.LiquidCal, 'struct')
    LegacyBpodLiquidCalibration('Calibrate');
    return
end

% If it's already open then raise the existing liquid calibrator window
if isfield(BpodSystem.GUIHandles, 'LiquidCalibrator')
    if isfield(BpodSystem.GUIHandles.LiquidCalibrator.GUIHandles, 'MainFig') && ~verLessThan('MATLAB', '8.4')
        if isgraphics(BpodSystem.GUIHandles.LiquidCalibrator.GUIHandles.MainFig)
            figure(BpodSystem.GUIHandles.LiquidCalibrator.GUIHandles.MainFig);
            return;
        end
    end
end

savepath = fullfile(BpodLib.path.getPath('liquidcalibration', BpodSystem), 'LiquidCalibration.json');
BpodLib.calibration.liquid.LiquidCalibratorUI(BpodSystem.CalibrationTables.LiquidCal,... 
    'BpodSystem', BpodSystem, 'savepath', savepath, 'source', 'statemachine', 'target', 'FSM_Onboard');

end