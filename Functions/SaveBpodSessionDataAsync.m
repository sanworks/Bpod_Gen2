%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright(C) 2019 Sanworks LLC, Stony Brook, New York, USA

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
function SaveBpodSessionDataAsync(filename, SessionData, protocolQueue)
    % SaveBpodSessionDataAsync: Save Bpod data asynchronously (in a background process)

    saverQueue = parallel.pool.PollableDataQueue;
    send(protocolQueue, saverQueue);

    DefaultFields = {'Info';
                'nTrials';
                'RawEvents';
                'RawData';
                'TrialStartTimestamp';
                'TrialEndTimestamp';
                'SettingsFile'}

    new = false;

    while true

        %%% wait for new data %%%
        [trialData, ok] = poll(saverQueue, .1);

        if ok

            if islogical(trialData)

                if ~trialData
                    break;
                end

            else

                new = true;

                %%% update Bpod Data %%%

                nTrials = trialData.nTrials;

                SessionData.nTrials = nTrials;
                SessionData.RawEvents.Trial{nTrials} = trialData.RawEvents;
                SessionData.RawData.OriginalStateNamesByNumber{nTrials} = trialData.RawData.OriginalStateNamesByNumber;
                SessionData.RawData.OriginalStateData{nTrials} = trialData.RawData.OriginalStateData;
                SessionData.RawData.OriginalEventData{nTrials} = trialData.RawData.OriginalEventData;
                SessionData.RawData.OriginalStateTimestamps{nTrials} = trialData.RawData.OriginalStateTimestamps;
                SessionData.RawData.OriginalEventTimestamps{nTrials} = trialData.RawData.OriginalEventTimestamps;
                SessionData.RawData.StateMachineErrorCodes{nTrials} = trialData.RawData.StateMachineErrorCodes;
                SessionData.TrialStartTimestamp(nTrials) = trialData.TrialStartTimestamp;
                SessionData.TrialEndTimestamp(nTrials) = trialData.TrialEndTimestamp;

                %%% add additional fields manually added to trialData %%%

                trialDataFields = setdiff(fieldnames(trialData), DefaultFields);

                for f = 1:numel(trialDataFields)

                    if iscell(trialData.(trialDataFields{f}))
                        SessionData.(trialDataFields{f}){nTrials} = trialData.(trialDataFields{f});
                    else
                        SessionData.(trialDataFields{f})(nTrials) = trialData.(trialDataFields{f});
                    end

                end

            end

        elseif new

            %%% save to file %%%

            new = false;
            save(filename, 'SessionData');

        end

    end

end
