%{
----------------------------------------------------------------------------

This file is part of the Bpod Project
Copyright (C) 2014 Joshua I. Sanders, Cold Spring Harbor Laboratory, NY, USA

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
function Click2AFC
% This protocol demonstrates the Poisson Click task using Pulse Pal. 
% Written by Josh Sanders, 10/2014.
%
% SETUP
% You will need:
% - A Pulse Pal with software installed on this computer
% - A BNC cable between Bpod's BNC Output 1 and Pulse Pal's Trigger channel 1
% - Left and right speakers connected to Pulse Pal's output channels 1 and 2 respectively

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.StimulusDelayDuration = 0; % Duration of initial delay (s)
    S.GUI.TimeForResponse = 3; % Time after sampling for subject to respond (s)
    S.GUI.RewardAmount = 5; % amount of large reward delivered to the mouse in microliters
    S.GUI.TimeoutDuration = 2; % Duration of punishment timeout (s)
    S.GUI.StimulusDuration = 3; % Duration of the sound
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

%% Initialize and program Pulse Pal
%PulsePal
%load Click2AFCPulsePalProgram.mat
%ProgramPulsePal(ParameterMatrix);

%% Define trials
MaxTrials = 5000;
TrialTypes = ceil(rand(1,MaxTrials)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 200],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
BpodNotebook('init');

%% Main trial loop
for currentTrial = 1:MaxTrials 
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
    %FastClickTrain = GeneratePoissonClickTrain_PulsePal(20, S.GUI.StimulusDuration);
    %SlowClickTrain = GeneratePoissonClickTrain_PulsePal(10, S.GUI.StimulusDuration);
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1 
            LeftActionState = 'Reward'; RightActionState = 'Punish';
            ValveCode = 1; ValveTime = LeftValveTime;
            %SendCustomPulseTrain(2, FastClickTrain, ones(1,length(FastClickTrain))*5);
            %SendCustomPulseTrain(1, SlowClickTrain, ones(1,length(SlowClickTrain))*5);
        case 2
            LeftActionState = 'Punish'; RightActionState = 'Reward';
            ValveCode = 4; ValveTime = RightValveTime;
            %SendCustomPulseTrain(2, SlowClickTrain, ones(1,length(SlowClickTrain))*5);
            %SendCustomPulseTrain(1, Train, ones(1,length(FastClickTrain))*5);
    end
    sma = NewStateMatrix(); % Assemble state matrix
    sma = AddState(sma, 'Name', 'WaitForCenterPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'Delay'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', S.GUI.StimulusDelayDuration,...
        'StateChangeConditions', {'Tup', 'DeliverStimulus'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.StimulusDuration,...
        'StateChangeConditions', {'Tup', 'WaitForResponse', 'Port2Out', 'KillSound'},...
        'OutputActions', {'BNCState', 1});
    sma = AddState(sma, 'Name', 'KillSound', ...
        'Timer', .0005,...
        'StateChangeConditions', {'Tup', 'KillSound2'},...
        'OutputActions', {'BNCState', 0});
    sma = AddState(sma, 'Name', 'KillSound2', ...
        'Timer', .0005,...
        'StateChangeConditions', {'Tup', 'WaitForResponse'},...
        'OutputActions', {'BNCState', 1});
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.TimeForResponse,...
        'StateChangeConditions', {'Tup', 'exit', 'Port1In', LeftActionState, 'Port3In', RightActionState},...
        'OutputActions', {'PWM1', 255, 'PWM3', 255});
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'ValveState', ValveCode});
    sma = AddState(sma, 'Name', 'Punish', ...
        'Timer', S.GUI.TimeoutDuration,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'PWM1', 255, 'PWM3', 255});    
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition;
    if BpodSystem.BeingUsed == 0
        return
    end
end

function UpdateSideOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Punish(1))
        Outcomes(x) = 0;
    else
        Outcomes(x) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes)
