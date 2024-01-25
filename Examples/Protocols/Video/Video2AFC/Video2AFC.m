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

function Video2AFC

global BpodSystem % Imports the BpodSystem object to the function workspace

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %ul
    S.GUI.CueDelay = 0.2; % How long the mouse must poke in the center to activate the goal port
    S.GUI.ResponseTime = 5; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.RewardDelay = 0; % How long the mouse must wait in the goal port for reward to be delivered
    S.GUI.PunishTimeout = 3; % How long the mouse must wait in the goal port for reward to be delivered
end

%% Define trials
maxTrials = 1000;
trialTypes = ceil(rand(1,1000)*2);
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

%% Setup video
% Clear previous instances of the video server
if isfield(BpodSystem.PluginObjects, 'V') 
    BpodSystem.PluginObjects.V = [];
end
BpodSystem.PluginObjects.V = PsychToolboxVideoPlayer(2, 0, [0 0], [180 180], 0); 
                             % Assumes second monitor is screen #2. Sync patch = 180x180 pixels
BpodSystem.PluginObjects.V.SyncPatchIntensity = 140;

% Indicate loading to user
BpodSystem.PluginObjects.V.loadText(1, 'Loading...', '', 80);
BpodSystem.PluginObjects.V.play(1);

% Generate frames
maxVideoFrames = 60;
ySize = BpodSystem.PluginObjects.V.ViewPortDimensions(2);
xSize = BpodSystem.PluginObjects.V.ViewPortDimensions(1);
myVideoL = zeros(ySize,xSize, maxVideoFrames); % Initialize blank video
myVideoR = myVideoL;
stepSize = 10;
posL = 0; posR = 0;
for i = 1:maxVideoFrames
    gratingL = floor((sin((posL:xSize+posL-1)/50)+1)*128);
    gratingR = floor((sin((posR:xSize+posR-1)/50)+1)*128);
    myVideoL(:,:,i) = repmat(gratingL, ySize, 1);
    myVideoR(:,:,i) = repmat(gratingR, ySize, 1);
    posL = posL + stepSize;
    posR = posR - stepSize;
end

% Load frames to server
BpodSystem.PluginObjects.V.loadVideo(1, myVideoL);
BpodSystem.PluginObjects.V.loadVideo(2, myVideoR);

% Set params
BpodSystem.PluginObjects.V.TimerMode = 1;

% Clear screen
BpodSystem.PluginObjects.V.play(0);

% Set soft code handler
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlayVideo';

%% Main trial loop
for currentTrial = 1:maxTrials
    % Sync parameters with BpodParameterGUI plugin
    S = BpodParameterGUI('sync', S); 
    
    % Update GUI parameters
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); 
    leftValveTime = vt(1); 
    rightValveTime = vt(2);
    
    % Determine trial-specific state machine variables
    switch trialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            leftPokeAction = 'LeftRewardDelay'; 
            rightPokeAction = 'PunishTimeout'; 
            stimulusOutput = {'SoftCode', 1};
        case 2
            leftPokeAction = 'PunishTimeout'; 
            rightPokeAction = 'RightRewardDelay'; 
            stimulusOutput = {'SoftCode', 2};
    end

    % Assemble state machine description
    sma = NewStateMatrix();
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
        'StateChangeConditions', {'Port1In', leftPokeAction, 'Port3In', rightPokeAction, 'Tup', 'exit'},...
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
        'Timer', .5,...
        'StateChangeConditions', {'Tup', 'exit', 'Port1In', '>back', 'Port3In', '>back'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'PunishTimeout', ...
        'Timer', S.GUI.PunishTimeout,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'CorrectEarlyWithdrawal', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});

    % Run the trial and process data returned
    SendStateMachine(sma);
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
        BpodSystem.PluginObjects.V = []; % Clear video server
        return
    end
end
BpodSystem.PluginObjects.V = []; % Clear video server
