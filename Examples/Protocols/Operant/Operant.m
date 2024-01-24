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

% This protocol introduces a naive mouse to water available in ports 1 and 3
% using an intermittent reinforcement schedule.
%
% SETUP
% You will need:
% - A Bpod MouseBox (or equivalent) configured with 3 ports.
% - Place masking tape over the center port (Port 2).

function Operant

global BpodSystem % Imports the BpodSystem object to the function workspace

%% Session Setup

% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.CurrentBlock = 1; % Training level % 1 = Direct Delivery at both ports 2 = Poke for delivery
    S.GUI.RewardAmount = 5; %ul
    S.GUI.PortOutRegDelay = 0.5; % How long the mouse must remain out before poking back in
end

% Define trials
nSinglePokeTrials = 5;
nDoublePokeTrials = 5;
nTriplePokeTrials = 5;
nRandomTrials = 850;
maxTrials = nSinglePokeTrials+nDoublePokeTrials+nTriplePokeTrials+nRandomTrials;
trialTypes = [ones(1,nSinglePokeTrials) ones(1,nDoublePokeTrials)*2 ones(1,nTriplePokeTrials)*3 ceil(rand(1,nRandomTrials)*3)];
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots

% Initialize the scorecard GUI. 
outcomePlot = LiveOutcomePlot([1 2 3], {'Single', 'Double', 'Triple'}, trialTypes, 90); % Create an instance of the LiveOutcomePlot GUI
              % Arg1 = trialTypeManifest, a list of possible trial types (even if not yet in trialTypes).
              % Arg2 = trialTypeNames, a list of names for each trial type in trialTypeManifest
              % Arg3 = trialTypes, a list of integers denoting precomputed trial types in the session
              % Arg4 = nTrialsToShow, the number of trials to show
outcomePlot.RewardStateNames = {'LeftReward', 'RightReward'}; % List of state names where reward is delivered
                                                              % State names are set when states are defined below.
% Initialize Bpod notebook (for manual data annotation)
BpodNotebook('init'); 

% Initialize parameter GUI plugin
BpodParameterGUI('init', S); 

%% Main loop, runs once per trial
for currentTrial = 1:maxTrials
    % Sync parameters with BpodParameterGUI plugin
    S = BpodParameterGUI('sync', S); 

    % Update reward amounts
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); 
    leftValveTime = vt(1); 
    rightValveTime = vt(2);

    % Determine trial-specific state machine variables
    switch trialTypes(currentTrial) 
        case 1
            stateOnLeftPoke1 = 'LeftReward'; 
            stateOnRightPoke1 = 'RightReward';
            stateOnLeftPoke2 = 'LeftReward'; 
            stateOnRightPoke2 = 'RightReward'; 
        case 2
            stateOnLeftPoke1 = 'WaitForPokeOut1'; 
            stateOnRightPoke1 = 'WaitForPokeOut1';
            stateOnLeftPoke2 = 'LeftReward'; 
            stateOnRightPoke2 = 'RightReward'; 
        case 3
            stateOnLeftPoke1 = 'WaitForPokeOut1'; 
            stateOnRightPoke1 = 'WaitForPokeOut1';
            stateOnLeftPoke2 = 'WaitForPokeOut2'; 
            stateOnRightPoke2 = 'WaitForPokeOut2';  
    end

    % Build the state machine description for this trial
    sma = NewStateMachine(); 
    sma = AddState(sma, 'Name', 'WaitForPoke1', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', stateOnLeftPoke1, 'Port3In', stateOnRightPoke1},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'WaitForPokeOut1', ...
        'Timer', S.GUI.PortOutRegDelay,...
        'StateChangeConditions', {'Port1Out', 'EnforcePokeOut1', 'Port3Out', 'EnforcePokeOut1'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'EnforcePokeOut1', ...
        'Timer', S.GUI.PortOutRegDelay,...
        'StateChangeConditions', {'Tup', 'WaitForPoke2'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'WaitForPoke2', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', stateOnLeftPoke2, 'Port3In', stateOnRightPoke2},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'WaitForPokeOut2', ...
        'Timer', S.GUI.PortOutRegDelay,...
        'StateChangeConditions', {'Port1Out', 'EnforcePokeOut2', 'Port3Out', 'EnforcePokeOut2'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'EnforcePokeOut2', ...
        'Timer', S.GUI.PortOutRegDelay,...
        'StateChangeConditions', {'Tup', 'WaitForPoke3'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'WaitForPoke3', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', 'LeftReward', 'Port3In', 'RightReward'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'LeftReward', ...
        'Timer', leftValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', 1}); 
    sma = AddState(sma, 'Name', 'RightReward', ...
        'Timer', rightValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', 4}); 
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', 10,...
        'StateChangeConditions', {'Tup', 'exit', 'Port1Out', 'ConfirmPortOut', 'Port3Out', 'ConfirmPortOut'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'ConfirmPortOut', ...
        'Timer', S.GUI.PortOutRegDelay,...
        'StateChangeConditions', {'Tup', 'exit', 'Port1In', 'Drinking', 'Port3In', 'Drinking'},...
        'OutputActions', {});

    % Send description to the Bpod State Machine device
    SendStateMachine(sma);

    % Run the trial
    RawEvents = RunStateMachine;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
        BpodSystem.Data.TrialTypes(currentTrial) = trialTypes(currentTrial); % Adds the trial type of the current trial to data
        outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.

    % Exit the session if the user has pressed the end button
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end
