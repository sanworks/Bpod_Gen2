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

% This protocol introduces a naive mouse to water available in ports 1 and 3. 
% Written by Josh Sanders, 5/2015.
%
% SETUP
% You will need:
% - A Bpod MouseBox (or equivalent) configured with 3 ports.
% - Place masking tape over the center port (Port 2).

function Operant

global BpodSystem % Imports the BpodSystem object to the function workspace

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.CurrentBlock = 1; % Training level % 1 = Direct Delivery at both ports 2 = Poke for delivery
    S.GUI.RewardAmount = 5; %ul
    S.GUI.PortOutRegDelay = 0.5; % How long the mouse must remain out before poking back in
end

%% Define trials
nSinglePokeTrials = 5;
nDoublePokeTrials = 5;
nTriplePokeTrials = 5;
nRandomTrials = 850;
maxTrials = nSinglePokeTrials+nDoublePokeTrials+nTriplePokeTrials+nRandomTrials;
trialTypes = [ones(1,nSinglePokeTrials) ones(1,nDoublePokeTrials)*2 ones(1,nTriplePokeTrials)*3 ceil(rand(1,nRandomTrials)*3)];
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot',...
                                                   'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',trialTypes);
BpodNotebook('init'); % Initialize Bpod notebook (for manual data annotation)
BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% Main trial loop
for currentTrial = 1:maxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); leftValveTime = vt(1); rightValveTime = vt(2); % Update reward amounts
    switch trialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            stateOnLeftPoke1 = 'LeftReward'; stateOnRightPoke1 = 'RightReward';
            stateOnLeftPoke2 = 'LeftReward'; stateOnRightPoke2 = 'RightReward'; 
        case 2
            stateOnLeftPoke1 = 'WaitForPokeOut1'; stateOnRightPoke1 = 'WaitForPokeOut1';
            stateOnLeftPoke2 = 'LeftReward'; stateOnRightPoke2 = 'RightReward'; 
        case 3
            stateOnLeftPoke1 = 'WaitForPokeOut1'; stateOnRightPoke1 = 'WaitForPokeOut1';
            stateOnLeftPoke2 = 'WaitForPokeOut2'; stateOnRightPoke2 = 'WaitForPokeOut2';  
    end
    sma = NewStateMachine(); % Initialize new state machine description
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
    SendStateMachine(sma);
    RawEvents = RunStateMachine;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
        BpodSystem.Data.TrialTypes(currentTrial) = trialTypes(currentTrial); % Adds the trial type of the current trial to data
        update_outcome_plot(trialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

function update_outcome_plot(TrialTypes, Data)
global BpodSystem
outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Drinking(1))
        outcomes(x) = 1;
    else
        outcomes(x) = 3;
    end
end
TrialTypeOutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',Data.nTrials+1,TrialTypes,outcomes);
