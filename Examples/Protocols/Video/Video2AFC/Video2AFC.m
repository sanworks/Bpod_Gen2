%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

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
function Video2AFC
% This protocol is a starting point for a visual 2AFC task using a screen.
% After initiating each trial with a center-poke,
% the subject is rewarded for choosing left if the video is bright, and right if it is darker.
% Written by Josh Sanders, 8/2022.
%
% SETUP
% You will need:
% - PsychToolbox installed
% - A second monitor attached to the PC
% - A Bpod MouseBox (or equivalent) configured with 3 ports.
% > Connect the left port in the box to Bpod Port#1.
% > Connect the center port in the box to Bpod Port#2.
% > Connect the right port in the box to Bpod Port#3.
% > Make sure the liquid calibration tables for ports 1 and 3 have 
%   calibration curves with several points surrounding 3ul.
%
% IMPORTANT NOTE: On Windows 10, after starting the protocol, the console GUI may be frozen.
% you'll need to select the console GUI application from the taskbar while running a trial to regain control. 
% This is a known bug, and will be fixed in a future release.

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %ul
    S.GUI.CueDelay = 0.2; % How long the mouse must poke in the center to activate the goal port
    S.GUI.ResponseTime = 5; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.RewardDelay = 0; % How long the mouse must wait in the goal port for reward to be delivered
    S.GUI.PunishDelay = 3; % How long the mouse must wait in the goal port for reward to be delivered
end

%% Define trials
MaxTrials = 1000;
TrialTypes = ceil(rand(1,1000)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
BpodNotebook('init');
BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% Setup video
if isfield(BpodSystem.PluginObjects, 'V') % Clear previous instances of the video server
    BpodSystem.PluginObjects.V = [];
end
BpodSystem.PluginObjects.V = PsychToolboxVideoPlayer(2, 0, [0 0], [180 180], 0); % Assumes second monitor is screen #2. Sync patch = 180x180 pixels
BpodSystem.PluginObjects.V.SyncPatchIntensity = 140;
% Indicate loading
BpodSystem.PluginObjects.V.loadText(1, 'Loading...', '', 80);
BpodSystem.PluginObjects.V.play(1);
MaxVideoFrames = 60;
Ysize = BpodSystem.PluginObjects.V.ViewPortDimensions(2);
Xsize = BpodSystem.PluginObjects.V.ViewPortDimensions(1);
MyVideoL = zeros(Ysize,Xsize, MaxVideoFrames); % Initialize blank video
MyVideoR = MyVideoL;
StepSize = 10;
PosL = 0; PosR = 0;
for i = 1:MaxVideoFrames
    GratingL = floor((sin((PosL:Xsize+PosL-1)/50)+1)*128);
    GratingR = floor((sin((PosR:Xsize+PosR-1)/50)+1)*128);
    MyVideoL(:,:,i) = repmat(GratingL, Ysize, 1);
    MyVideoR(:,:,i) = repmat(GratingR, Ysize, 1);
    PosL = PosL + StepSize;
    PosR = PosR - StepSize;
end
BpodSystem.PluginObjects.V.loadVideo(1, MyVideoL);
BpodSystem.PluginObjects.V.loadVideo(2, MyVideoR);
BpodSystem.PluginObjects.V.TimerMode = 1;
BpodSystem.PluginObjects.V.play(0);
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlayVideo';

%% Main trial loop
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            LeftPokeAction = 'LeftRewardDelay'; RightPokeAction = 'Punish'; StimulusOutput = {'SoftCode', 1};
        case 2
            LeftPokeAction = 'Punish'; RightPokeAction = 'RightRewardDelay'; StimulusOutput = {'SoftCode', 2};
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
        'StateChangeConditions', {'Port1In', LeftPokeAction, 'Port3In', RightPokeAction, 'Tup', 'exit'},...
        'OutputActions', {'SoftCode', 255}); 
    sma = AddState(sma, 'Name', 'LeftRewardDelay', ...
        'Timer', S.GUI.RewardDelay,...
        'StateChangeConditions', {'Tup', 'LeftReward', 'Port1Out', 'CorrectEarlyWithdrawal'},...
        'OutputActions', {}); % Stop the video
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
    SendStateMachine(sma);
    RawEvents = RunStateMachine;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        BpodSystem.PluginObjects.V = [];
        return
    end
end
BpodSystem.PluginObjects.V = [];

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
