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

% This protocol demonstrates a 2AFC task using PsychToolbox to generate sound stimuli.
% Subjects initialize each trial with a poke into port 2. After a delay, a tone plays.
% Subjects are rewarded for responding left for low-pitch tones, and right for high.
%
% SETUP
% You will need:
% - Windows 7-10 or Ubuntu 14.XX with the -lowlatency package installed
% - ASUS Xonar DX, AE or SE sound card installed. If using Windows, install
%   the drivers from the ASUS website, and configure the ASIO latency to 1ms in the ASUS config panel.
% - PsychToolbox 3 installed
% - The Xonar DX comes with an RCA cable. Use an RCA to BNC adapter to
%    connect channel 3 to one of Bpod's BNC input channels for a record of the
%    exact time each sound played. For Xonar AE and SE, you'll need the
%    Bpod AudioSync module.

function PsychToolboxSound

global BpodSystem % Imports the BpodSystem object to the function workspace

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.TrainingLevel = 2; % Configurable reward condition schemes. 'BothCorrect' rewards either side.
    S.GUIMeta.TrainingLevel.Style = 'popupmenu'; % the GUIMeta field is used by the ParameterGUI plugin to customize UI objects.
    S.GUIMeta.TrainingLevel.String = {'BothCorrect', '2AFC'};
    S.GUI.SoundDuration = 0.5; % Duration of sound (s)
    S.GUI.SinWaveFreqLeft = 500; % Frequency of left cue
    S.GUI.SinWaveFreqRight = 2000; % Frequency of right cue
    S.GUI.RewardAmount = 5; % in ul
    S.GUI.StimulusDelayDuration = 0; % Seconds before stimulus plays on each trial
    S.GUI.TimeForResponse = 5; % Seconds after stimulus sampling for a response
    S.GUI.PunishTimeoutDuration = 2; % Seconds to wait on errors before next trial can start
    S.GUI.PunishSound = 1; % if 1, plays a white noise pulse on error. if 0, no sound is played.
    S.GUIMeta.PunishSound.Style = 'checkbox';
    S.GUIPanels.Task = {'TrainingLevel', 'RewardAmount', 'PunishSound'}; % GUIPanels organize the parameters into groups.
    S.GUIPanels.Sound = {'SinWaveFreqLeft', 'SinWaveFreqRight', 'SoundDuration'};
    S.GUIPanels.Time = {'StimulusDelayDuration', 'TimeForResponse', 'PunishTimeoutDuration'};
end

%% Define trials
maxTrials = 5000;
trialTypes = ceil(rand(1,maxTrials)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
% Initialize the outcome plot 
outcomePlot = LiveOutcomePlot([1 2], {'Left', 'Right'}, trialTypes, 90); % Create an instance of the LiveOutcomePlot GUI
              % Arg1 = trialTypeManifest, a list of possible trial types (even if not yet in trialTypes).
              % Arg2 = trialTypeNames, a list of names for each trial type in trialTypeManifest
              % Arg3 = trialTypes, a list of integers denoting precomputed trial types in the session
              % Arg4 = nTrialsToShow, the number of trials to show
outcomePlot.RewardStateNames = {'Reward'}; % List of state names where reward was delivered
outcomePlot.PunishStateNames = {'Punish'}; % List of state names where choice was incorrect and negatively reinforced

% Total Reward display (online display of the total amount of liquid reward earned)
TotalRewardDisplay('init'); 

% Initialize parameter GUI plugin
BpodParameterGUI('init', S); 

%% Define stimuli and send to sound server
sf = 192000; % Sound card sampling rate
leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
errorSound = ((rand(1,sf*.5)*2) - 1);
% Generate early withdrawal sound
w1 = GenerateSineWave(sf, 1000, .5); w2 = GenerateSineWave(sf, 1200, .5); earlyWithdrawalSound = w1+w2;
p = sf/100; Interval = p;
for x = 1:50 % Gate waveform to create pulses
    earlyWithdrawalSound(p:p+Interval) = 0;
    p = p+(Interval*2);
end

% Program sound server
if ~isfield(BpodSystem.PluginObjects, 'Sound')
    BpodSystem.PluginObjects.Sound = PsychToolboxAudio;
end
BpodSystem.PluginObjects.Sound.load(1, leftSound);
BpodSystem.PluginObjects.Sound.load(2, rightSound);
BpodSystem.PluginObjects.Sound.load(3, errorSound);
BpodSystem.PluginObjects.Sound.load(4, earlyWithdrawalSound);

% Set soft code handler to trigger sounds
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlaySound';

%% Main trial loop
for currentTrial = 1:maxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    if S.GUI.PunishSound
        errorOutputAction = {'SoftCode', 3};
    else
        errorOutputAction = {};
    end
    leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
    rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
    BpodSystem.PluginObjects.Sound.load(1, leftSound);
    BpodSystem.PluginObjects.Sound.load(2, rightSound);
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); leftValveTime = vt(1); rightValveTime = vt(2); % Update reward amounts
    switch trialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            outputActionArgument = {'SoftCode', 1, 'BNCState', 1}; 
            leftActionState = 'Reward'; rightActionState = 'Punish'; correctWithdrawalEvent = 'Port1Out';
            valveCode = 1; valveTime = leftValveTime;
        case 2
            outputActionArgument = {'SoftCode', 2, 'BNCState', 1};
            leftActionState = 'Punish'; rightActionState = 'Reward'; correctWithdrawalEvent = 'Port3Out';
            valveCode = 4; valveTime = rightValveTime;
    end
    sma = NewStateMachine(); % Initialize new state machine description
    sma = AddState(sma, 'Name', 'WaitForCenterPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'Delay'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', S.GUI.StimulusDelayDuration,...
        'StateChangeConditions', {'Tup', 'DeliverStimulus'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.SoundDuration,...
        'StateChangeConditions', {'Tup', 'WaitForResponse', 'Port2Out', 'EarlyWithdrawal'},...
        'OutputActions', outputActionArgument);
    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'EarlyWithdrawalPunish'},...
        'OutputActions', {'SoftCode', 255});
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.TimeForResponse,...
        'StateChangeConditions', {'Tup', 'exit', 'Port1In', leftActionState, 'Port3In', rightActionState},...
        'OutputActions', {'PWM1', 255, 'PWM3', 255});
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', valveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', valveCode});
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', 10,...
        'StateChangeConditions', {'Tup', 'exit', correctWithdrawalEvent, 'exit'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Punish', ...
        'Timer', S.GUI.PunishTimeoutDuration,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', errorOutputAction);
    sma = AddState(sma, 'Name', 'EarlyWithdrawalPunish', ...
        'Timer', S.GUI.PunishTimeoutDuration,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'SoftCode', 4});
    SendStateMachine(sma); % Send the state matrix to the Bpod device
    RawEvents = RunStateMachine; % Run the trial and return events
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned (i.e. if not final trial, interrupted by user)
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = trialTypes(currentTrial); % Adds the trial type of the current trial to data
        outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot
        if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
            TotalRewardDisplay('add', rewardAmount);
        end
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0 % If protocol was stopped, exit the loop
        return
    end
end
