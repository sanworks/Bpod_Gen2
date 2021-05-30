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
function [oldData, newData] = SplitBpodSessionData(data, splitTime)

    split_time_from_start = data.TrialStartTimestamp(1) + splitTime;
    newTrials = find(data.TrialStartTimestamp > split_time_from_start);

    oldData = data;
    newData = struct();

    if ~isempty(newTrials)

        dataFields = fieldnames(data);
        defaults = {'Info', 'nTrials', 'RawEvents', 'RawData', 'TrialStartTimestamp', 'TrialEndTimestamp'};
        manuallyAdded = setdiff(dataFields, defaults);

        newData = data;

        dayOffset = data.TrialStartTimestamp(newTrials(1)) - data.TrialStartTimestamp(1);
        timeOffsetOld = (data.TrialEndTimestamp(1) - data.TrialStartTimestamp(1)) / 1000;
        timeOffsetNew = (data.TrialEndTimestamp(newTrials(1)) - data.TrialStartTimestamp(newTrials(1))) / 1000;
        fullOffset = -timeOffsetOld + dayOffset + timeOffsetNew;

        if isfield(newData.Info, 'FileStartTime_MATLAB')
            newStartTime = newData.Info.FileStartTime_MATLAB + seconds(fullOffset);
        else
            newStartTime = newData.Info.SessionStartTime_MATLAB + seconds(fullOffset);
        end

        newData.Info.FileDate = datestr(newStartTime, 1)
        newData.Info.FileStartTime_UTC = datestr(newStartTime, 13)
        newData.Info.FileStartTime_MATLAB = newStartTime;

        % create new struct with only new trials

        newData.nTrials = length(newTrials);
        newData.RawEvents.Trial = newData.RawEvents.Trial(newTrials(1):end);
        newData.RawData.OriginalStateNamesByNumber = newData.RawData.OriginalStateNamesByNumber(newTrials(1):end);
        newData.RawData.OriginalStateData = newData.RawData.OriginalStateData(newTrials(1):end);
        newData.RawData.OriginalEventData = newData.RawData.OriginalEventData(newTrials(1):end);
        newData.RawData.OriginalStateTimestamps = newData.RawData.OriginalStateTimestamps(newTrials(1):end);
        newData.RawData.OriginalEventTimestamps = newData.RawData.OriginalEventTimestamps(newTrials(1):end);
        newData.RawData.StateMachineErrorCodes = newData.RawData.StateMachineErrorCodes(newTrials(1):end);
        newData.TrialStartTimestamp = newData.TrialStartTimestamp(newTrials(1):end);
        newData.TrialEndTimestamp = newData.TrialEndTimestamp(newTrials(1):end);

        for f = 1:length(manuallyAdded)

            if iscell(newData.(manuallyAdded{f}))
                newData.(manuallyAdded{f}) = newData.(manuallyAdded{f})(newTrials(1):end);
            else
                newData.(manuallyAdded{f}) = newData.(manuallyAdded{f})(newTrials(1):end);
            end

        end

        % remove new trials from original data

        oldData.nTrials = newTrials(1) - 1;
        oldData.RawEvents.Trial(newTrials(1):end) = [];
        oldData.RawData.OriginalStateNamesByNumber(newTrials(1):end) = [];
        oldData.RawData.OriginalStateData(newTrials(1):end) = [];
        oldData.RawData.OriginalEventData(newTrials(1):end) = [];
        oldData.RawData.OriginalStateTimestamps(newTrials(1):end) = [];
        oldData.RawData.OriginalEventTimestamps(newTrials(1):end) = [];
        oldData.RawData.StateMachineErrorCodes(newTrials(1):end) = [];
        oldData.TrialStartTimestamp(newTrials(1):end) = [];
        oldData.TrialEndTimestamp(newTrials(1):end) = [];

        for f = 1:length(manuallyAdded)

            if length(oldData.(manuallyAdded{f})) >= oldData.nTrials
                oldData.(manuallyAdded{f})(newTrials(1):end) = [];
            end

        end

    end

end
