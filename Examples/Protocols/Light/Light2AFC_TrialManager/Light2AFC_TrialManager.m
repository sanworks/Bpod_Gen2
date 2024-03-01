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

% This protocol is a starting point for a visual 2AFC task like Light2AFC, 
% but using the BpodTrialManager class instead of RunStateMachine().
% TrialManager allows heavy MATLAB-side processing (i.e., plots,
% saving data, computing and loading the next trial's state machine)
% without causing a long period of dead-time between trials. For more info
% see the TrialManager documentation on the Bpod wiki:
% https://sanworks.github.io/Bpod_Wiki/function-reference/running-statemachine/#bpodtrialmanager
%
% After initiating each trial with a center-poke,
% the subject is rewarded for choosing the port that is lit.
%
% SETUP
% You will need:
% - A set of 3 behavior ports (e.g. Bpod MouseBox).
% > Connect the left port in the box to State Machine Behavior Port#1.
% > Connect the center port in the box to State Machine Behavior Port#2.
% > Connect the right port in the box to State Machine Behavior Port#3.
% > Make sure the liquid calibration tables for ports 1 and 3 have 
%   calibration curves with several points surrounding 3ul.

function Light2AFC_TrialManager

global BpodSystem % Imports the BpodSystem object to the function workspace

%% Session Setup

% Create trial manager object
trialManager = BpodTrialManager;

% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %ul
    S.GUI.CueDelay = 0.2; % How long the mouse must poke in the center to activate the goal port
    S.GUI.ResponseTime = 5; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.RewardDelay = 0; % How long the mouse must wait in the goal port for reward to be delivered
    S.GUI.PunishTimeout = 3; %% How long the mouse must wait to start the next trial if it makes the wrong choice (s)
end

% Define trial types
maxTrials = 1000;
trialTypes = ceil(rand(1,maxTrials)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots

% Initialize the outcome plot 
outcomePlot = LiveOutcomePlot([1 2], {'Left', 'Right'}, trialTypes, 90); % Create an instance of the LiveOutcomePlot GUI
              % Arg1 = trialTypeManifest, a list of possible trial types (even if not yet in trialTypes).
              % Arg2 = trialTypeNames, a list of names for each trial type in trialTypeManifest
              % Arg3 = trialTypes, a list of integers denoting precomputed trial types in the session
              % Arg4 = nTrialsToShow, the number of trials to show
outcomePlot.CorrectStateNames = {'LeftRewardDelay', 'RightRewardDelay'}; % List of state names where choice was correct
                                                                         % State names are set when states are defined below.
outcomePlot.RewardStateNames = {'LeftReward', 'RightReward'}; % List of state names where reward was delivered
outcomePlot.PunishStateNames = {'PunishTimeout'}; % List of state names where choice was incorrect and negatively reinforced

% Initialize Bpod notebook (for manual data annotation)                                                          
BpodNotebook('init'); 

% Initialize parameter GUI plugin
BpodParameterGUI('init', S); 

% Initialize the pokes plot
PokesPlot('init', getStateColors, getPokeColors);

%% Prepare and start first trial
sma = PrepareStateMachine(S, trialTypes, 1, []); % Prepare state machine for trial 1 with empty "current events" variable
trialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.

%% Main loop, runs once per trial
for currentTrial = 1:maxTrials
    currentTrialEvents = trialManager.getCurrentEvents({'LeftReward', 'RightReward', 'TimeOutState', 'PunishTimeout'}); 
                                       % Hangs here until Bpod enters one of the listed trigger states, 
                                       % then returns current trial's states visited + events captured to this point
    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
    if currentTrial < maxTrials
        [sma, S] = PrepareStateMachine(S, trialTypes, currentTrial+1, currentTrialEvents); % Prepare next state machine.
        % Since PrepareStateMachine is a function with a separate workspace, pass any local variables needed to make 
        % the state machine as fields of settings struct S e.g. S.learningRate = 0.2.
        SendStateMachine(sma, 'RunASAP'); % With TrialManager, you can send the next trial's state machine during the current trial
    end
    RawEvents = trialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if currentTrial < maxTrials
        trialManager.startTrial(); % Start processing the next trial's events (call with no argument since SM was already sent)
    end
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned from last trial, update plots and save data
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
        BpodSystem.Data.TrialTypes(currentTrial) = trialTypes(currentTrial); % Adds the trial type of the current trial to data
        PokesPlot('update'); % Update Pokes Plot
        outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
end

function [sma, S] = PrepareStateMachine(S, TrialTypes, currentTrial, currentTrialEvents)
% In this case, we don't need trial events to build the state machine - but
% they are available in currentTrialEvents.
S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); % Update reward amounts
leftValveTime = vt(1); 
rightValveTime = vt(2); 
switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
    case 1
        leftPokeAction = 'LeftRewardDelay'; 
        rightPokeAction = 'PunishTimeout'; 
        stimulusOutput = {'PWM1', 255}; % PWM1 controls the LED light intensity of port 1 (0-255)
    case 2
        leftPokeAction = 'PunishTimeout'; 
        rightPokeAction = 'RightRewardDelay'; 
        stimulusOutput = {'PWM3', 255}; % PWM3 controls the LED light intensity of port 3 (0-255)
end
sma = NewStateMachine(); % Initialize new state machine description
sma = SetCondition(sma, 1, 'Port1', 0); % Condition 1: Port 1 low (test subject is out)
sma = SetCondition(sma, 2, 'Port3', 0); % Condition 2: Port 3 low (test subject is out)
sma = AddState(sma, 'Name', 'WaitForPoke', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port2In', 'CueDelay'},...
    'OutputActions', {}); 
sma = AddState(sma, 'Name', 'CueDelay', ...
    'Timer', S.GUI.CueDelay,...
    'StateChangeConditions', {'Port2Out', 'WaitForPoke', 'Tup', 'WaitForPortOut'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'WaitForPortOut', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port2Out', 'WaitForResponse'},...
    'OutputActions', stimulusOutput);
sma = AddState(sma, 'Name', 'WaitForResponse', ...
    'Timer', S.GUI.ResponseTime,...
    'StateChangeConditions', {'Port1In', leftPokeAction, 'Port3In', rightPokeAction, 'Tup', 'TimeOutState'},...
    'OutputActions', stimulusOutput); 
sma = AddState(sma, 'Name', 'LeftRewardDelay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup', 'LeftReward', 'Port1Out', 'CorrectEarlyWithdrawal'},...
    'OutputActions', {}); 
sma = AddState(sma, 'Name', 'RightRewardDelay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup', 'RightReward', 'Port3Out', 'CorrectEarlyWithdrawal'},...
    'OutputActions', {}); 
sma = AddState(sma, 'Name', 'LeftReward', ...
    'Timer', leftValveTime,...
    'StateChangeConditions', {'Tup', 'DrinkingLeft'},...
    'OutputActions', {'ValveState', 1}); 
sma = AddState(sma, 'Name', 'RightReward', ...
    'Timer', rightValveTime,...
    'StateChangeConditions', {'Tup', 'DrinkingRight'},...
    'OutputActions', {'ValveState', 4}); 
sma = AddState(sma, 'Name', 'DrinkingLeft', ...
    'Timer', 0,...
    'StateChangeConditions', {'Condition1', 'DrinkingGrace'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'DrinkingRight', ...
    'Timer', 0,...
    'StateChangeConditions', {'Condition2', 'DrinkingGrace'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'DrinkingGrace', ...
    'Timer', 0.5,...
    'StateChangeConditions', {'Tup', '>exit', 'Port1In', '>back', 'Port3In', '>back'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'PunishTimeout', ...
    'Timer', S.GUI.PunishTimeout,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'CorrectEarlyWithdrawal', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'TimeOutState', ... % Record events while next trial's state machine is sent
    'Timer', 0.25,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {});


function state_colors = getStateColors
state_colors = struct( ...
    'WaitForPoke', [0.5 0.5 1],...
    'CueDelay',0.3*[1 1 1],...
    'WaitForPortOut', 0.75*[1 1 0],...
    'WaitForResponse',[0.5 1 1],... 
    'LeftRewardDelay',[.2,.2,1],...
    'RightRewardDelay',[.7,.7,1],...
    'LeftReward',[0,1,0],...
    'RightReward',[0,0,1],...
    'DrinkingLeft',[1,0,0],...
    'DrinkingRight',[1,0,0],...
    'DrinkingGrace',[1,0.3,0],...
    'PunishTimeout',[1,0,0],...
    'CorrectEarlyWithdrawal',0.75*[0,1,1],...
    'TimeOutState',[1,0,0]);

function poke_colors = getPokeColors
poke_colors = struct( ...
      'L', 0.6*[1 0.66 0], ...
      'C', [0 0 0], ...
      'R',  0.9*[1 0.66 0]);
