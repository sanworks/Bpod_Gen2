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

% This protocol is a starting point for a visual 2AFC task.
% After initiating each trial with a center-poke,
% the subject is rewarded for choosing the port that is lit.
%
% Updated to demo FlexI/O analog input, 9/2022. Flex I/O Ch1 is acquired in
% tandem with the behavior data, and threshold crossing events are logged.
% In this example, analog threshold events do not drive state transitions.
%
% SETUP
% You will need:
% - Bpod State Machine 2+ (or a newer model with Flex I/O channels)
% - A Bpod MouseBox (or equivalent) configured with 3 ports.
% > Connect the left port in the box to State Machine Behavior Port#1.
% > Connect the center port in the box to State Machine Behavior Port#2.
% > Connect the right port in the box to State Machine Behavior Port#3.
% > Make sure the liquid calibration tables for ports 1 and 3 have 
%   calibration curves with several points surrounding 3ul.

function FlexIOAnalogLight2AFC

global BpodSystem % Imports the BpodSystem object to the function workspace

%% Verify state machine model
if BpodSystem.MachineType < 4
    error('The FlexIOAnalogLight2AFC protocol requires a state machine with Flex I/O channels (e.g. State Machine 2+).')
end

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %ul
    S.GUI.CueDelay = 0.2; % How long the test subject must poke in the center to activate the goal port
    S.GUI.ResponseTime = 5; % How long until the test subject must make a choice, or forefeit the trial
    S.GUI.RewardDelay = 0; % How long the test subject must wait in the goal port for reward to be delivered
    S.GUI.PunishDelay = 3; % How long the test subject must wait in the goal port for reward to be delivered
end

% Configure Flex I/O Channels
BpodSystem.FlexIOConfig.channelTypes = [2 1 4 4];
BpodSystem.FlexIOConfig.threshold1 = ones(1,4)*4; % In range 0-5
BpodSystem.FlexIOConfig.polarity1 = zeros(1,4); % Polarity 0: Threshold activated when analog is > thresh
BpodSystem.FlexIOConfig.threshold2 = ones(1,4)*1; % In range 0-5
BpodSystem.FlexIOConfig.polarity2 = ones(1,4); % Polarity 1: Threshold activated when analog is < thresh
BpodSystem.FlexIOConfig.thresholdMode = ones(1,4); % Mode 1: Crossing threshold 1 enables threshold 2, crossing 2 enables 1

%% Define trials
maxTrials = 1000;
trialTypes = ceil(rand(1,1000)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off',... 
                                                       'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-trialTypes);
BpodNotebook('init');
BpodParameterGUI('init', S); % Initialize parameter GUI plugin
BpodSystem.startAnalogViewer; % Initialize analog viewer GUI (optional)

%% Main trial loop
for currentTrial = 1:maxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); leftValveTime = vt(1); rightValveTime = vt(2); % Update reward amounts
    switch trialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            leftPokeAction = 'LeftRewardDelay'; rightPokeAction = 'Punish'; stimulusOutput = {'PWM1', 255};
        case 2
            leftPokeAction = 'Punish'; rightPokeAction = 'RightRewardDelay'; stimulusOutput = {'PWM3', 255};
    end
    sma = NewStateMatrix(); % Assemble state matrix
    sma = AddState(sma, 'Name', 'WaitForPoke1', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'CueDelay'},...
        'OutputActions', {'AnalogThreshEnable', 1}); 
    sma = AddState(sma, 'Name', 'CueDelay', ...
        'Timer', S.GUI.CueDelay,...
        'StateChangeConditions', {'Port2Out', 'WaitForPoke1', 'Tup', 'WaitForPortOut'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'WaitForPortOut', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2Out', 'WaitForResponse'},...
        'OutputActions', stimulusOutput);
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.ResponseTime,...
        'StateChangeConditions', {'Port1In', leftPokeAction, 'Port3In', rightPokeAction, 'Tup', 'exit'},...
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
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', 1}); 
    sma = AddState(sma, 'Name', 'RightReward', ...
        'Timer', rightValveTime,...
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
        cleanup;
        return
    end
end
cleanup;

function cleanup()
global BpodSystem
BpodSystem.Data = AddFlexIOAnalogData(BpodSystem.Data, 'Volts', 1); % Adds all data in the Flex I/O analog data file (if present) 
                  % to BpodSystem.Data. The analog binary data file is retained for the user to delete if desired.
                  % Args 2 and 3 are optional. 'Volts' saves volts. Use 'Bits' for a smaller data file with samples given in bits.
                  % The second argument may be set to '1' to add a trial-aligned copy of the analog data: 
                  % a cell array with one cell of data per trial.
SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file

function update_outcome_plot(TrialTypes, Data)
global BpodSystem
outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Drinking(1))
        outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
        outcomes(x) = 0;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.CorrectEarlyWithdrawal(1))
        outcomes(x) = 2;
    else
        outcomes(x) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,outcomes);
