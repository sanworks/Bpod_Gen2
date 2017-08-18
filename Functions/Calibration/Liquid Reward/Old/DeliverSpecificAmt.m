function DeliverSpecificAmt

% This function is part of the liquid calibrator. It delivers a specific
% amount of liquid to valves specified in the calibration GUI

handles=guidata(LiquidCalibrationManager);

figure(handles.TestSpecificAmtFig);
% In case the GUI has already been used, reset values.
set(handles.EnterMeasurementButton, 'Enable', 'on');
set(handles.ResultsListbox, 'String', cell(1,1))
set(handles.ResultsListbox, 'Value', 1)
set(handles.MeasuredValveText, 'String', '1')
InvalidParams = 0; % if invalid params are found, this is set to "1" and delivery is skipped

% Figure out which valves to test
ValveLogic = zeros(1,8);
ValveLogic(1) = get(handles.CB1b, 'Value');
ValveLogic(2) = get(handles.CB2b, 'Value');
ValveLogic(3) = get(handles.CB3b, 'Value');
ValveLogic(4) = get(handles.CB4b, 'Value');
ValveLogic(5) = get(handles.CB5b, 'Value');
ValveLogic(6) = get(handles.CB6b, 'Value');
ValveLogic(7) = get(handles.CB7b, 'Value');
ValveLogic(8) = get(handles.CB8b, 'Value');
TargetValves = find(ValveLogic);
% Sanity-check target valves
if isempty(TargetValves)
    InvalidParams = 1;
end
nValves = length(TargetValves);
% Figure out amount to test
LiquidAmount = get(handles.SpecificAmtEdit, 'String');
% Sanity-check liquid amount
if isnan(str2double(LiquidAmount))
    InvalidParams = 1;
end
LiquidAmount = round(str2double(LiquidAmount));
if (LiquidAmount < 0) || (LiquidAmount > 1000)
    InvalidParams = 1;
end

if InvalidParams == 0
% Convert liquid amount to pulse duration using current table
PulseDurations = GetValveTimes(LiquidAmount, TargetValves);

% Figure out how many pulses to deliver
nPulses = 50+(get(handles.nPulsesDropmenu, 'Value')*50);

% Set valve request window
set(handles.MeasuredValveText, 'String', num2str(TargetValves(1)));
drawnow;
% Call calibration script
    LiquidRewardCal(nPulses, TargetValves, PulseDurations, .2) 

    Ok = 1; % Returned from function. If OK=1, system prompts user to enter measurements
else
    Ok = 0;
    warndlg('Invalid settings detected. Check setup.', 'Error', 'modal');
end

% Get measurements
set(handles.MeasuredAmtEdit, 'String', '', 'Enable', 'on');
uicontrol(handles.MeasuredAmtEdit);

% At this point, the rest of the procedure is handled by the "enter
% measurement" button callback, EnterTestCalMeasurement.m