%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2019 Sanworks LLC, Stony Brook, New York, USA

----------------------------------------------------------------------------

This program is free software:you can redistribute it and / or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see < http: // www.gnu.org / licenses /> .
%}
function [oldData, newData] = SplitBpodSessionData(data, trialNum)

    dataFields = fieldnames(data);
    defaults = {'Info', 'nTrials', 'RawEvents', 'RawData', 'TrialStartTimestamp', 'TrialEndTimestamp'};
    manuallyAdded = setdiff(dataFields, defaults);

    newData = data;
    oldData = data;

    if (trialNum > 0) && (trialNum <= data.nTrials)

        % create new struct with only new trials

        newData.nTrials = data.nTrials - trialNum + 1;
        newData.RawEvents.Trial = newData.RawEvents.Trial{trialNum:end};
        newData.RawData.OriginalStateNamesByNumber = newData.RawData.OriginalStateNamesByNumber{trialNum:end};
        newData.RawData.OriginalStateData = newData.RawData.OriginalStateData{trialNum:end};
        newData.RawData.OriginalEventData = newData.RawData.OriginalEventData{trialNum:end};
        newData.RawData.OriginalStateTimestamps = newData.RawData.OriginalStateTimestamps{trialNum:end};
        newData.RawData.OriginalEventTimestamps = newData.RawData.OriginalEventTimestamps{trialNum:end};
        newData.RawData.StateMachineErrorCodes = newData.RawData.StateMachineErrorCodes{trialNum:end};
        newData.TrialStartTimestamp = newData.TrialStartTimestamp(trialNum:end);
        newData.TrialEndTimestamp = newData.TrialEndTimestamp(trialNum:end);

        for f = 1:length(manuallyAdded)

            if iscell(newData.(manuallyAdded{f}))
                newData.(manuallyAdded{f}) = newData.(manuallyAdded{f}){trialNum:end};
            else
                newData.(manuallyAdded{f}) = newData.(manuallyAdded{f})(trialNum:end);
            end

        end

        % remove new trials from original data

        oldData.nTrials = trialNum - 1;
        oldData.RawEvents.Trial(trialNum:end) = [];
        oldData.RawData.OriginalStateNamesByNumber(trialNum:end) = [];
        oldData.RawData.OriginalStateData(trialNum:end) = [];
        oldData.RawData.OriginalEventData(trialNum:end) = [];
        oldData.RawData.OriginalStateTimestamps(trialNum:end) = [];
        oldData.RawData.OriginalEventTimestamps(trialNum:end) = [];
        oldData.RawData.StateMachineErrorCodes(trialNum:end) = [];
        oldData.TrialStartTimestamp(trialNum:end) = [];
        oldData.TrialEndTimestamp(trialNum:end) = [];

        for f = 1:length(manuallyAdded)

            if length(oldData.(manuallyAdded{f})) >= oldData.nTrials
                oldData.(manuallyAdded{f})(trialNum:end) = [];
            end

        end

    end

end
