function EnterTestCalMeasurement

% Sequentially enters measurements into the Test pt Calibration GUI
handles=guidata(LiquidCalibrationManager);
figure(handles.TestSpecificAmtFig);

ToleranceLevelStrings = get(handles.ToleranceDropmenu, 'String');
ToleranceLevel = str2double(ToleranceLevelStrings{get(handles.ToleranceDropmenu, 'Value')})/100; % Fraction of intended amount by which measured amount is allowed to differ from intended amount

% Figure out which valves were tested
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

InvalidParams = 0;
MeasuredLiquidAmount = get(handles.MeasuredAmtEdit, 'String');
% Sanity-check liquid amount
if isnan(str2double(MeasuredLiquidAmount))
    InvalidParams = 1;
end
nPulses = 50+(get(handles.nPulsesDropmenu, 'Value')*50);
MeasuredLiquidAmount = str2double(MeasuredLiquidAmount);
if (MeasuredLiquidAmount < 0) || (MeasuredLiquidAmount > 1000)
    InvalidParams = 1;
end
IntendedLiquidAmount = get(handles.SpecificAmtEdit, 'String');
IntendedLiquidAmount = str2double(IntendedLiquidAmount);
if InvalidParams == 0
    ValveID = str2double(get(handles.MeasuredValveText, 'String'));
    ListboxMeasurements = get(handles.ResultsListbox, 'String');
    if isempty(ListboxMeasurements{1})
        nEntries = 0;
    else
        nEntries = length(ListboxMeasurements);
    end
    CurrentEntry = nEntries+1;
    MeasuredLiquidAmount = MeasuredLiquidAmount/nPulses; % Amount per pulse in ml
    MeasuredLiquidAmount = MeasuredLiquidAmount*1000; % Amount per pulse in ul
    ToleranceIntervalLowBound = IntendedLiquidAmount - (IntendedLiquidAmount*ToleranceLevel);
    ToleranceIntervalHighBound = IntendedLiquidAmount + (IntendedLiquidAmount*ToleranceLevel);
    WithinTolerance = ((MeasuredLiquidAmount >= ToleranceIntervalLowBound) && (MeasuredLiquidAmount <= ToleranceIntervalHighBound));
    if WithinTolerance == 1
        ListboxMeasurements{CurrentEntry} = ['<html><FONT COLOR="#009900">Valve ' num2str(ValveID) ': ' num2str(IntendedLiquidAmount) 'ul indended. ' num2str(MeasuredLiquidAmount) 'ul measured. PASS</FONT></html>'];
    else
        ListboxMeasurements{CurrentEntry} = ['<html><FONT COLOR="#ff0000">Valve ' num2str(ValveID) ': ' num2str(IntendedLiquidAmount) 'ul indended. ' num2str(MeasuredLiquidAmount) 'ul measured. FAIL</FONT></html>'];
    end
    set(handles.ResultsListbox, 'String', ListboxMeasurements)
    ValveIDPos = find(TargetValves == ValveID);
    if ValveIDPos < length(TargetValves)
        NextValve = TargetValves(ValveIDPos+1);
        set(handles.MeasuredValveText, 'String', num2str(NextValve));
    else
        set(handles.EnterMeasurementButton, 'Enable', 'off');
    end
else
    warndlg('Invalid liquid amount.', 'Error', 'modal');
end