function suggestedDuration_ms = suggestDuration(valveobject, rangeLow, rangeHigh)
%duration = suggestDuration(valve)
% Suggest a duration for the valve based on its type and size.

if ~isempty(valveobject.Durations)
    durations = valveobject.Durations';
    amounts =  valveobject.Amounts';
else
    durations = [];
    amounts = [];
end

nMeasurements = numel(durations);

if nMeasurements > 1 % Use trinomial curve fit to predict next measurement
    % Construct a vector ranging from rangeLow to rangeHigh, that also includes any existing measurements within that range
    DistanceVector = amounts;
    if isempty(find(amounts == rangeLow))
        DistanceVector = [DistanceVector rangeLow];
    end
    if isempty(find(amounts == rangeHigh))
        DistanceVector = [DistanceVector rangeHigh];
    end
    DistanceVector = sort(DistanceVector);
    Startpoint = find(DistanceVector == rangeLow);
    Endpoint = find(DistanceVector == rangeHigh);
    DistanceVector = DistanceVector(Startpoint:Endpoint);

    % Find the amount that is halfway between the two largest distances
    Distances = zeros(1,length(DistanceVector));
    for y = 2:length(DistanceVector)
        Distances(y) = abs(DistanceVector(y) - DistanceVector(y-1));
    end
    [~, MaxDistancePos] = max(Distances);
    SuggestedAmount = DistanceVector(MaxDistancePos-1) + (DistanceVector(MaxDistancePos)-DistanceVector(MaxDistancePos-1))/2;

    if nMeasurements > 3
        suggestedDuration_ms = valveobject.getValveTime(SuggestedAmount);
    elseif nMeasurements == 3
        Coeffs = polyfit(amounts, durations, 2);
        suggestedDuration_ms = round(polyval(Coeffs, SuggestedAmount));
    elseif nMeasurements == 2
        Coeffs = polyfit(amounts, durations, 1);
        suggestedDuration_ms = round(polyval(Coeffs, SuggestedAmount));
    end
else
    if nMeasurements == 1
        % Use a linear estimate
        ulPerMs = amounts/durations;
        if (amounts < rangeLow) || (amounts > rangeHigh)
            TargetAmount = (rangeHigh - rangeLow)/2;
        else
            BottomPart = amounts - rangeLow;
            TopPart = rangeHigh - amounts;
            if BottomPart > TopPart
                TargetAmount = rangeLow+(BottomPart/2);
            else
                TargetAmount = rangeHigh-(TopPart/2);
            end
            
        end
        suggestedDuration_ms = round(TargetAmount/ulPerMs);
    else
        % Use an estimate of the middle of the range based on range and our experience with
        % the CSHL configuration (nResearch pinch valves, silastic
        % tubing, specs in Bpod literature)
        suggestedDuration_ms = mean([rangeHigh rangeLow])*4;
    end
end