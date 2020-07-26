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

% Return a struct of data from the last trial
% Can be run after AddTrialEvents
% Result can be passed to SaveBpodSessionDataAsync

function trialData = GatherTrialData(varargin)

    global BpodSystem

    trialData = struct();

    trialData.nTrials = BpodSystem.Data.nTrials;
    trialData.RawEvents = BpodSystem.Data.RawEvents.Trial{end};

    trialData.RawData = struct();
    trialData.RawData.OriginalStateNamesByNumber = BpodSystem.Data.RawData.OriginalStateNamesByNumber{end};
    trialData.RawData.OriginalStateData = BpodSystem.Data.RawData.OriginalStateData{end};
    trialData.RawData.OriginalEventData = BpodSystem.Data.RawData.OriginalEventData{end};
    trialData.RawData.OriginalStateTimestamps = BpodSystem.Data.RawData.OriginalStateTimestamps{end};
    trialData.RawData.OriginalEventTimestamps = BpodSystem.Data.RawData.OriginalEventTimestamps{end};
    trialData.RawData.StateMachineErrorCodes = BpodSystem.Data.RawData.StateMachineErrorCodes{end};

    trialData.TrialStartTimestamp = BpodSystem.Data.TrialStartTimestamp(end);
    trialData.TrialEndTimestamp = BpodSystem.Data.TrialEndTimestamp(end);

    %%% add additional fields manually added BpodSystem.Data %%%

    BpodDataFields = fieldnames(BpodSystem.Data);

    for f = 1:numel(BpodDataFields)

        if ~isfield(trialData, BpodDataFields{f})

            if iscell(BpodDataFields{f})
                trialData.(BpodDataFields{f}) = BpodSystem.Data.(BpodDataFields{f}){end};
            else
                trialData.(BpodDataFields{f}) = BpodSystem.Data.(BpodDataFields{f})(end);
            end

        end

    end

    %%% add additional fields by name, value pair %%%

    index = 1;

    while index < nargin
        trialData.(varargin{index}) = varargin{index + 1};
        index = index + 2;
    end

end
