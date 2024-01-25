%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

% AddTrialEvents formats trial events returned by RunStateMachine() or BpodTrialManager() 
% and adds them to a human-readable session data struct. 
% 
% Arguments:
% -sd: A MATLAB struct to store session data. This can be empty (e.g. on the first trial of 
%      the session) or a data struct previously passed to AddTrialEvents on earlier trials. 
%      Certain fields of te will be updated with the new data in rawTrialEvents. Additional
%      user-added fields of sd will be ignored, and must be manually updated by the user.
%      Hint: If BpodSystem.Data is passed in as sd, it can be stored later to the
%      current data file with SaveBpodSessionData();
% -rawTrialEvents: A raw trial events struct returned by RunStateMachine() or BpodTrialManager.
%
% Returns:
% -updatedSD: A session data structure with added data from rawTrialEvents.
% Fields of updatedTE added/updated by AddTrialEvents are:
% -Info: A struct with information about the system hardware, software and experimental protocol
% -nTrials: The number of trials completed
% -RawData: An unformatted copy of the data in rawTrialEvents
% -RawEvents: A human-readable copy of the data in rawTrialEvents,
%             organized by trial.
% -TrialStartTimestamp: The trial start time of each trial in the dataset. Units = seconds
% -TrialEndTimestamp: The trial end time of each trial in the dataset. Units = seconds
% -StateMachineErrorCodes: Error codes returned by the system on each trial. 0 = no error.
% -SettingsFile: The settings struct selected by the user on starting the session
%
% Example usage: sd = AddTrialEvents(sd, rawTrialEvents);
% Note: If BpodSystem.Data is passed as sd, it can be saved to the current data file with SaveBpodSessionData();
% BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents);

function updatedSD = AddTrialEvents(sd, rawTrialEvents)

global BpodSystem % Import the global BpodSystem object

stateNames = BpodSystem.LastStateMatrix.StateNames;

% Add system, experiment and settings metadata if this is the first trial in the dataset
if isfield(sd, 'RawEvents')
    trialNum = length(sd.RawEvents.Trial) + 1;
else
    % This is the first pass to AddTrialEvents. Add session metadata.
    trialNum = 1;
    sd.Info = struct;
    sd.Info.BpodSoftwareVersion = BpodSoftwareVersion_Semantic;
    if BpodSystem.EmulatorMode == 1
        sd.Info.StateMachineVersion = 'Bpod 0.7-1.0 EMULATOR';
    else
        sd.Info.StateMachineVersion = ['Bpod ' BpodSystem.HW.StateMachineModel];
        sd.Info.Firmware = struct;
        sd.Info.Firmware.StateMachine = BpodSystem.FirmwareVersion;
        if BpodSystem.FirmwareVersion > 22
            sd.Info.Firmware.StateMachine_Minor = BpodSystem.HW.minorFirmwareVersion;
        end
        for i = 1:BpodSystem.Modules.nModules
            if BpodSystem.Modules.Connected(i)
                sd.Info.Firmware.(BpodSystem.Modules.Name{i}) = BpodSystem.Modules.FirmwareVersion(i);
            end
        end
        if BpodSystem.FirmwareVersion > 22
            sd.Info.CircuitRevision = struct;
            sd.Info.CircuitRevision = BpodSystem.HW.CircuitRevision;
        end
        sd.Info.Modules = BpodSystem.Modules;
    end
    sd.Info.PCsetup = struct;
    sd.Info.PCsetup.OS = BpodSystem.HostOS;
    sd.Info.PCsetup.MATLABver = version('-release');
    sd.Info.SessionDate = datestr(now, 1);
    if ~isempty(BpodSystem.ProtocolStartTime)
        theTime = BpodSystem.ProtocolStartTime/100000;
    else % The function is called outside the context of a session. Use current time.
        theTime = now;
    end
    sd.Info.SessionStartTime_UTC = datestr(theTime, 13);
    sd.Info.SessionStartTime_MATLAB = theTime;

    % Add settings struct selected for the session in the launch manager
    sd.SettingsFile = BpodSystem.ProtocolSettings;
end

% Update number of trials
sd.nTrials = trialNum;

% Parse and add raw events for this trial
states = rawTrialEvents.States;
nPossibleStates = length(stateNames);
visitedStates = zeros(1,nPossibleStates);

% determine unique states while preserving visited order
uniqueStates = zeros(1,nPossibleStates);
nUniqueStates = 0;
uniqueStateIndexes = zeros(1,length(states));
for x = 1:length(states)
    if sum(uniqueStates == states(x)) == 0
        nUniqueStates = nUniqueStates + 1;
        uniqueStates(nUniqueStates) = states(x);
        visitedStates(states(x)) = 1;
        uniqueStateIndexes(x) = nUniqueStates;
    else
        uniqueStateIndexes(x) = find(uniqueStates == states(x));
    end
end
uniqueStates = uniqueStates(1:nUniqueStates);
uniqueStateDataMatrices = cell(1,nUniqueStates);

% Create a 2-d matrix for each state with entry and exit timestamps for each visit
for x = 1:length(states)
    uniqueStateDataMatrices{uniqueStateIndexes(x)} = [uniqueStateDataMatrices{uniqueStateIndexes(x)};... 
        [rawTrialEvents.StateTimestamps(x) rawTrialEvents.StateTimestamps(x+1)]];
end
for x = 1:nUniqueStates
    sd.RawEvents.Trial{trialNum}.States.(stateNames{uniqueStates(x)}) = uniqueStateDataMatrices{x};
end
for x = 1:nPossibleStates
    if visitedStates(x) == 0
        sd.RawEvents.Trial{trialNum}.States.(stateNames{x}) = [NaN NaN];
    end
end

% Create a 2-d matrix for each event with timestamps for each occurance
events = rawTrialEvents.Events;
for x = 1:length(events)
    sd.RawEvents.Trial{trialNum}.Events.(BpodSystem.StateMachineInfo.EventNames{events(x)}) =... 
        rawTrialEvents.EventTimestamps(events == events(x));
end

% Add an unformatted copy of rawTrialEvents to sd
sd.RawData.OriginalStateNamesByNumber{trialNum} = stateNames;
sd.RawData.OriginalStateData{trialNum} = rawTrialEvents.States;
sd.RawData.OriginalEventData{trialNum} = rawTrialEvents.Events;
sd.RawData.OriginalStateTimestamps{trialNum} = rawTrialEvents.StateTimestamps;
sd.RawData.OriginalEventTimestamps{trialNum} = rawTrialEvents.EventTimestamps;

% Add trial start/end timestamps
sd.TrialStartTimestamp(trialNum) = rawTrialEvents.TrialStartTimestamp;
sd.TrialEndTimestamp(trialNum) = rawTrialEvents.TrialEndTimestamp;

% Add error codes
sd.RawData.StateMachineErrorCodes{trialNum} = rawTrialEvents.ErrorCodes;

updatedSD = sd;
