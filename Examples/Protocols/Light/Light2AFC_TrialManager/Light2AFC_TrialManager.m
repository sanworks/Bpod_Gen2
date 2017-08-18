%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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
function Light2AFC_TrialManager
% This protocol is a starting point for a visual 2AFC task like Light2AFC, 
% but using the TrialManager object instead of RunStateMachine().
% TrialManager allows heavy MATLAB-side processing (here, the PokesPlot plugin)
% without causing a long period of dead-time between trials. For more info
% see the TrialManager documentation on the Bpod wiki.
%
% After initiating each trial with a center-poke,
% the subject is rewarded for choosing the port that is lit.
% Written by Josh Sanders, 4/2017.
%
% SETUP
% You will need:
% - A Bpod MouseBox (or equivalent) configured with 3 ports.
% > Connect the left port in the box to Bpod Port#1.
% > Connect the center port in the box to Bpod Port#2.
% > Connect the right port in the box to Bpod Port#3.
% > Make sure the liquid calibration tables for ports 1 and 3 have 
%   calibration curves with several points surrounding 3ul.

global BpodSystem
%% Create trial manager object
TrialManager = TrialManagerObject;

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %ul
    S.GUI.CueDelay = 0.2; % How long the mouse must poke in the center to activate the goal port
    S.GUI.ResponseTime = 5; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.RewardDelay = 0; % How long the mouse must wait in the goal port for reward to be delivered
    S.GUI.PunishDelay = 3; % How long the mouse must wait in the goal port for reward to be delivered
end

%% Define trial types
MaxTrials = 1000;
TrialTypes = ceil(rand(1,MaxTrials)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
tic;
%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [50 540 1000 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
BpodNotebook('init');
BpodParameterGUI('init', S); % Initialize parameter GUI plugin   
PokesPlot('init', getStateColors, getPokeColors);
sma = PrepareStateMachine(S, TrialTypes, 1, []); % Prepare state machine for trial 1 with empty "current events" variable
TrialManager.startTrial(sma); % Starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.

%% Main trial loop
for currentTrial = 1:MaxTrials
    currentTrialEvents = TrialManager.getCurrentEvents({'LeftReward', 'RightReward', 'TimeOutState'}); 
                                       % Hangs here until Bpod enters one of the listed trigger states, 
                                       % then returns current trial's states visited + events captured to this point
    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
    [sma, S] = PrepareStateMachine(S, TrialTypes, currentTrial+1, currentTrialEvents); % Prepare next state machine.
    % Since PrepareStateMachine is a function with a separate workspace, pass any local variables needed to make 
    % the state machine as fields of settings struct S e.g. S.learningRate = 0.2.
    RawEvents = TrialManager.getTrialData; % Hangs here until trial is over, then returns full trial's raw data
    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    TrialManager.startTrial(sma); % Start next trial's state machine
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned from last trial, update plots and save data
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        PokesPlot('update');
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
end

function [sma, S] = PrepareStateMachine(S, TrialTypes, currentTrial, currentTrialEvents)
% In this case, we don't need trial events to build the state machine - but
% they are available in currentTrialEvents.
S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
    case 1
        LeftPokeAction = 'LeftRewardDelay'; RightPokeAction = 'Punish'; StimulusOutput = {'PWM1', 255};
    case 2
        LeftPokeAction = 'Punish'; RightPokeAction = 'RightRewardDelay'; StimulusOutput = {'PWM3', 255};
end
sma = NewStateMatrix(); % Assemble state matrix
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
    'OutputActions', StimulusOutput);
sma = AddState(sma, 'Name', 'WaitForResponse', ...
    'Timer', S.GUI.ResponseTime,...
    'StateChangeConditions', {'Port1In', LeftPokeAction, 'Port3In', RightPokeAction, 'Tup', 'TimeOutState'},...
    'OutputActions', StimulusOutput); 
sma = AddState(sma, 'Name', 'LeftRewardDelay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup', 'LeftReward', 'Port1Out', 'CorrectEarlyWithdrawal'},...
    'OutputActions', {}); 
sma = AddState(sma, 'Name', 'RightRewardDelay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup', 'RightReward', 'Port3Out', 'CorrectEarlyWithdrawal'},...
    'OutputActions', {}); 
sma = AddState(sma, 'Name', 'LeftReward', ...
    'Timer', LeftValveTime,...
    'StateChangeConditions', {'Tup', 'Drinking'},...
    'OutputActions', {'ValveState', 1}); 
sma = AddState(sma, 'Name', 'RightReward', ...
    'Timer', RightValveTime,...
    'StateChangeConditions', {'Tup', 'Drinking'},...
    'OutputActions', {'ValveState', 4}); 
sma = AddState(sma, 'Name', 'Drinking', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port1Out', 'DrinkingGrace', 'Port3Out', 'DrinkingGrace'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'DrinkingGrace', ...
    'Timer', .5,...
    'StateChangeConditions', {'Tup', 'exit', 'Port1In', 'Drinking', 'Port3In', 'Drinking'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'Punish', ...
    'Timer', S.GUI.PunishDelay,...
    'StateChangeConditions', {'Tup', 'exit'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'CorrectEarlyWithdrawal', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'exit'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'TimeOutState', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'exit'},...
    'OutputActions', {});

function UpdateSideOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Drinking(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
        Outcomes(x) = 0;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.CorrectEarlyWithdrawal(1))
        Outcomes(x) = 2;
    else
        Outcomes(x) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);

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
    'Drinking',[1,0,0],...
    'DrinkingGrace',[1,0.3,0],...
    'Punish',[1,0,0],...
    'CorrectEarlyWithdrawal',0.75*[0,1,1],...
    'TimeOutState',[1,0,0]);
function poke_colors = getPokeColors
poke_colors = struct( ...
      'L', 0.6*[1 0.66 0], ...
      'C', [0 0 0], ...
      'R',  0.9*[1 0.66 0]);