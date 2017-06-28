function AddSuggestions
handles=guidata(LiquidCalibrationManager);
figure(handles.RecommendedMeasureFig);



% Figure out which valves were to be targeted
ValveLogic = zeros(1,8);
ValveLogic(1) = get(handles.CB1, 'Value');
ValveLogic(2) = get(handles.CB2, 'Value');
ValveLogic(3) = get(handles.CB3, 'Value');
ValveLogic(4) = get(handles.CB4, 'Value');
ValveLogic(5) = get(handles.CB5, 'Value');
ValveLogic(6) = get(handles.CB6, 'Value');
ValveLogic(7) = get(handles.CB7, 'Value');
ValveLogic(8) = get(handles.CB8, 'Value');

TargetValves = find(ValveLogic);
nTargetValves = length(TargetValves);
CalTable = handles.LiquidCal;
CalPending = handles.PendingMeasurements;
RangeLow = str2double(get(handles.LowRangeEdit, 'String'));
RangeHigh = str2double(get(handles.HighRangeEdit, 'String'));
SelectedValve = get(handles.listbox1, 'Value');
CurrentEntryString = get(handles.listbox2, 'String');

% Sanity check RangeLow and RangeHigh
InvalidParams = 0;

if isnan(RangeLow)
    InvalidParams = 1;
else
    if (RangeLow < 1) || (RangeLow > 1000)
        InvalidParams = 1;
    end
end
if isnan(RangeHigh)
    InvalidParams = 1;
else
    if (RangeHigh < 1) || (RangeHigh > 1000) || (RangeHigh < RangeLow)
        InvalidParams = 1;
    end
end

if InvalidParams == 0
    for x = TargetValves
        ThisValveTable = CalTable(x).Table;
        if ~isempty(ThisValveTable)
            MeasuredAmounts = ThisValveTable(:,2)';
            ValveDurations = ThisValveTable(:,1)';
            nMeasurements = length(MeasuredAmounts);
        else
            MeasuredAmounts = [];
            nMeasurements = 0;
        end
        if nMeasurements > 1 % Use trinomial curve fit to predict next measurement
            DistanceVector = MeasuredAmounts;
            if isempty(find(MeasuredAmounts == RangeLow))
                DistanceVector = [DistanceVector RangeLow];
            end
            if isempty(find(MeasuredAmounts == RangeHigh))
                DistanceVector = [DistanceVector RangeHigh];
            end
            DistanceVector = sort(DistanceVector);
            Startpoint = find(DistanceVector == RangeLow);
            Endpoint = find(DistanceVector == RangeHigh);
            DistanceVector = DistanceVector(Startpoint:Endpoint);
            Distances = zeros(1,length(DistanceVector));
            for y = 2:length(DistanceVector)
                    Distances(y) = abs(DistanceVector(y) - DistanceVector(y-1));
            end
            [MaxDistance, MaxDistancePos] = max(Distances);
            SuggestedAmount = DistanceVector(MaxDistancePos-1) + (DistanceVector(MaxDistancePos)-DistanceVector(MaxDistancePos-1))/2;
            if nMeasurements > 3
                SuggestedValveDuration = round(polyval(CalTable(x).TrinomialCoeffs,SuggestedAmount));
            elseif nMeasurements == 3
                Coeffs = polyfit(MeasuredAmounts, ValveDurations, 2);
                SuggestedValveDuration = round(polyval(Coeffs, SuggestedAmount));
            elseif nMeasurements == 2
                Coeffs = polyfit(MeasuredAmounts, ValveDurations, 1);
                SuggestedValveDuration = round(polyval(Coeffs, SuggestedAmount));
            end
        else
            if nMeasurements == 1
                % Use a linear estimate 
                ulPerMs = MeasuredAmounts/ValveDurations;
                if (MeasuredAmounts < RangeLow) || (MeasuredAmounts > RangeHigh)
                    TargetAmount = (RangeHigh - RangeLow)/2;
                else
                    BottomPart = MeasuredAmounts - RangeLow;
                    TopPart = RangeHigh - MeasuredAmounts;
                    if BottomPart > TopPart
                        TargetAmount = RangeLow+(BottomPart/2);
                    else
                        TargetAmount = RangeHigh-(TopPart/2);
                    end
                    
                end
                SuggestedValveDuration = round(TargetAmount/ulPerMs);
            else
                % Use an estimate of the middle of the range based on range and our experience with
                % the CSHL configuration (nResearch pinch valves, silastic
                % tubing, specs in Bpod literature)
                SuggestedValveDuration = mean([RangeHigh RangeLow])*4;
            end
        end
        ThisValvePending = CalPending{x};
        NonDuplicate = 0;
        if isempty(ThisValvePending)
            ThisValvePending(1) = SuggestedValveDuration;
            NonDuplicate = 1;
        else
            if isempty(find(ThisValvePending == SuggestedValveDuration))
                ThisValvePending(length(ThisValvePending)+1) = SuggestedValveDuration;
                NonDuplicate = 1;
            end
        end
        
        if NonDuplicate == 1 % If this measurement hasn't already been added to pending
            CalPending{x} = ThisValvePending;
            if x == SelectedValve
                CurrentEntryString{nMeasurements+1} = ['<html><FONT COLOR="#ff0000">**PENDING MEASUREMENT: '  num2str(SuggestedValveDuration) 'ms</FONT></html>'];
                set(handles.listbox2, 'String', CurrentEntryString);
            end
            CalPending{x} = ThisValvePending;
        end
    end
    handles.PendingMeasurements = CalPending;
    handles.LiquidCal(1).CalibrationTargetRange = [RangeLow RangeHigh];
    guidata(LiquidCalibrationManager, handles);
    close(handles.RecommendedMeasureFig);
else
    if (RangeHigh == 0) || (RangeLow == 0)
        warndlg('Range minimum and maximum must be non-zero.', 'Error', 'modal');
    else
        warndlg('Invalid range entered.', 'Error', 'modal');
    end
end


