% Add pending measurement from prompt window to calibraiton manager main
% window
function AddPendingMeasurement
global Measurement2add
handles=guidata(LiquidCalibrationManager);
ValueEntered = get(handles.AmountEntry, 'String');
ValidEntry = 1;
CandidateValue = str2double(ValueEntered);
if isnan(CandidateValue)
    ValidEntry = 0;
elseif CandidateValue < 1
    ValidEntry = 0;
elseif CandidateValue > 5000
    ValidEntry = 0;
end
if ValidEntry == 1
    Measurement2add = CandidateValue;
else
    Measurement2add = NaN;
end
close(handles.ValueEntryFig);