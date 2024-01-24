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

% This protocol showcases analog acquisition with the analog input module during a visual 2AFC task.
% After initiating each trial with a center-poke,
% the subject is rewarded for choosing the port that is lit.
% Analog signals are captured from channels 1+2 at 1kHz, displayed on the scope() GUI and logged to 
% a data file alongside the behavior data.
% During each trial, sync bytes are explicitly sent from the state machine to the analog input module, 
% at trial start (0), stimulus onset(1), choice (2) and trial end (3). 
% Each sync event will be recorded and timestamped in the analog input module dataset.
% Separately, a voltage threshold is set on analog input Ch1 at 2.5V. Threshold crossing events are 
% sent to the state machine.
%
% SETUP
% You will need:
% - 3 Behavior ports or lickometers with LEDs.
% - A Bpod analog input module and any signals you want to capture on channels 1 and 2
% > Connect the left port in the box to Bpod Port#1.
% > Connect the center port in the box to Bpod Port#2.
% > Connect the right port in the box to Bpod Port#3.
% > Connect the analog input module's 'State Machine' port to a free 'Module' port on the state machine
% > Click the 'USB' icon on the Bpod console, and pair the analog input module with its USB serial port (e.g. 'COM3')
% > Make sure the liquid calibration tables for ports 1 and 3 have 
%   calibration curves with several points surrounding 3ul.

function Light2AFC_AnalogStreaming

global BpodSystem % Imports the BpodSystem object to the function workspace

%% Session Setup
% Assert Analog Input module is present + USB-paired (via USB button on console GUI)
BpodSystem.assertModule('AnalogIn', 1); % The second argument (1) indicates that AnalogIn must be paired with its USB serial port

% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %ul
    S.GUI.CueDelay = 0.2; % How long the mouse must poke in the center to activate the goal port
    S.GUI.ResponseTime = 5; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.RewardDelay = 0; % How long the mouse must wait in the goal port for reward to be delivered
    S.GUI.PunishDelay = 3; % How long the mouse must wait in the goal port for reward to be delivered
end

% Define trials
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

% Initialize parameter GUI plugin
BpodParameterGUI('init', S); 

%% Setup analog input module
A = BpodAnalogIn(BpodSystem.ModuleUSB.AnalogIn1); % Create an instance of the Analog Input module
A.SamplingRate = 1000; % Hz
A.nActiveChannels = 2; % Record from up to 2 channels
A.Stream2USB(1:2) = 1; % Configure only channels 1 and 2 for USB streaming
A.SMeventsEnabled(1) = 1; % Return threshold crossing events from Ch1
A.Thresholds(1) = 2.5; % Set voltage threshold of Ch1 to 2.5V
A.ResetVoltages(1) = 1; % Voltage must return below 1V before another threshold crossing event can be triggered
A.startReportingEvents; % Enable threshold event signaling
behaviorDataFile = BpodSystem.Path.CurrentDataFile;
A.USBStreamFile = [behaviorDataFile(1:end-4) '_Alg.mat']; % Set datafile for analog data captured in this session
A.scope; % Launch Scope GUI
A.scope_StartStop % Start USB streaming + data logging

%% Main trial loop
for currentTrial = 1:maxTrials
    % Sync parameters with BpodParameterGUI plugin
    S = BpodParameterGUI('sync', S); 
    
    % Update reward amounts
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); 
    leftValveTime = vt(1); 
    rightValveTime = vt(2); 

    % Determine trial-specific state machine variables
    switch trialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            leftPokeAction = 'LeftRewardDelay'; rightPokeAction = 'PunishTimeout'; stimulusOutput = {'PWM1', 255}; 
        case 2
            leftPokeAction = 'PunishTimeout'; rightPokeAction = 'RightRewardDelay'; stimulusOutput = {'PWM3', 255};
    end

    % Build this trial's state machine description
    sma = NewStateMachine(); 
    sma = AddState(sma, 'Name', 'TrialStart', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'WaitForPoke'},...
        'OutputActions', {'AnalogIn1', ['#' 0]}); % Send sync byte 0 to analog input module to indicate trial start 
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
        'OutputActions', [stimulusOutput {'AnalogIn1', ['#' 1]}]); % Send sync byte 1 to analog input module to indicate stimulus onset
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.ResponseTime,...
        'StateChangeConditions', {'Port1In', leftPokeAction, 'Port3In', rightPokeAction, 'Tup', 'FinalState'},...
        'OutputActions', stimulusOutput); 
    sma = AddState(sma, 'Name', 'LeftRewardDelay', ...
        'Timer', S.GUI.RewardDelay,...
        'StateChangeConditions', {'Tup', 'LeftReward', 'Port1Out', 'CorrectEarlyWithdrawal'},...
        'OutputActions', {'AnalogIn1', ['#' 2]}); % Send sync byte 2 to analog input module to indicate choice
    sma = AddState(sma, 'Name', 'RightRewardDelay', ...
        'Timer', S.GUI.RewardDelay,...
        'StateChangeConditions', {'Tup', 'RightReward', 'Port3Out', 'CorrectEarlyWithdrawal'},...
        'OutputActions', {'AnalogIn1', ['#' 2]}); % Send sync byte 2 to analog input module to indicate choice
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
        'StateChangeConditions', {'Tup', 'FinalState', 'Port1In', 'Drinking', 'Port3In', 'Drinking'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'PunishTimeout', ...
        'Timer', S.GUI.PunishDelay,...
        'StateChangeConditions', {'Tup', 'FinalState'},...
        'OutputActions', {'AnalogIn1', ['#' 2]}); % Send sync byte 2 to analog input module to indicate choice
    sma = AddState(sma, 'Name', 'CorrectEarlyWithdrawal', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'FinalState'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'FinalState', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {'AnalogIn1', ['#' 3]}); % Send sync byte 3 to analog input module to indicate trial end

    % Send description to the Bpod State Machine device
    SendStateMachine(sma);

    % Run the trial
    RawEvents = RunStateMachine;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
        BpodSystem.Data.TrialTypes(currentTrial) = trialTypes(currentTrial); % Adds the trial type of the current trial to data
        outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        A.scope_StartStop; % Stop Oscope GUI
        A.endAcq; % Close Oscope GUI
        A.stopReportingEvents; % Stop sending events to state machine
        return
    end
end
