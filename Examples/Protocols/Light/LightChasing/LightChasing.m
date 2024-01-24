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

% This protocol is a simple light-chasing task. Enter lit ports to proceed
% through the trial. The protocol demonstrates use of a pushbutton callback 
% set up in settings struct S to manually flash the port lights.

function LightChasing

global BpodSystem % Imports the BpodSystem object to the function workspace

maxTrials = 10000;

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.StimulusDuration = 0.1; % Stimulus duration in seconds
    S.GUI.RewardAmount = 5; %ul
    S.GUI.FlashLeftLight = 'FlashLights(1)';
    S.GUIMeta.FlashLeftLight.Style = 'pushbutton';
    S.GUI.FlashRightLight = 'FlashLights(3)';
    S.GUIMeta.FlashRightLight.Style = 'pushbutton';
end

%% Define trials
trialTypes = round(rand(1,maxTrials)) + 1; % Randomly interleaved trial types 1 and 2
BpodSystem.Data.TrialTypes = trialTypes; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodNotebook('init'); % Bpod Notebook (to record text notes about the session or individual trials)
BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% Main trial loop
for currentTrial = 1:maxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]);   % Update reward amounts
    switch trialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            leftAction = 'Reward'; 
            rightAction = 'PunishTimeout'; 
            stimulusOutputActions = {'LED', 1}; 
            rewardOutputActions = {'Valve', 1}; 
            ValveTime = vt(1); 
        case 2
            rightAction = 'Reward'; 
            leftAction = 'PunishTimeout'; 
            stimulusOutputActions = {'LED', 3}; 
            rewardOutputActions = {'Valve', 3}; 
            ValveTime = vt(2);
    end
    sma = NewStateMachine(); % Initialize new state machine description
    sma = AddState(sma, 'Name', 'WaitForPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'DeliverStimulus'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.StimulusDuration,...
        'StateChangeConditions', {'Tup', 'WaitForResponse', 'Port2Out', 'WaitForResponse'},...
        'OutputActions', stimulusOutputActions);
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', leftAction, 'Port3In', rightAction},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', rewardOutputActions); 
    sma = AddState(sma, 'Name', 'PunishTimeout', ...
        'Timer', 5,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {}); 
    SendStateMachine(sma);
    RawEvents = RunStateMachine;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

