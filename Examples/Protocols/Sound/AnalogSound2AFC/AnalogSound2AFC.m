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

% This protocol demonstrates a 2AFC task using the analog output module to generate sound stimuli.
% Subjects initialize each trial with a poke into port 2. After a delay, a tone plays.
% If subjects exit the port before the tone is finished playing, a dissonant error sound is played.
% Subjects are rewarded for responding left for low-pitch tones, and right for high.
% A white noise pulse indicates incorrect choice.
% NOTE: We use AnalogOutputModule to play sound in this demo because the task's reinforcement cues 
% could be any 4 sounds that are easily discriminated from each other.
% A proper sound card is necessary for studies where auditory signal quality is critical to analysis.

function AnalogSound2AFC

global BpodSystem % Imports the BpodSystem object to the function workspace

%
% SETUP
% You will need:
% - A Bpod state machine v0.7 or newer
% - A Bpod analog output module, loaded with Bpod AudioPlayer firmware.
% - From the Bpod console, pair the AudioPlayer module with its USB serial port.
% - Connect the analog output module's State Machine port to Bpod
% - Connect channel 1 (or ch1+2) of the analog output module to an amplified speaker(s).

%% Assert AudioPlayer module is present + USB-paired (via USB button on console GUI)
BpodSystem.assertModule('AudioPlayer', 'USBpaired');

% Create an instance of the audioPlayer module
A = BpodAudioPlayer(BpodSystem.ModuleUSB.AudioPlayer1);

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
% Side Outcome Plot
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [50 540 1000 220],'name','Outcome plot',...
                                                       'numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .35 .89 .55]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-trialTypes);
TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% Define stimuli and send to analog module
sf = A.Info.maxSamplingRate; % Use max supported sampling rate
leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration)*.9; 
                             % Sampling freq (hz), Sine frequency (hz), duration (s)
rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration)*.9; 
errorSound = (rand(1,sf*.5)*2) - 1;

% Generate early withdrawal sound
w1 = GenerateSineWave(sf, 1000, .5); w2 = GenerateSineWave(sf, 1200, .5); earlyWithdrawalSound = w1+w2;
p = sf/100; Interval = p;
for x = 1:50 % Gate waveform to create pulses
    earlyWithdrawalSound(p:p+Interval) = 0;
    p = p+(Interval*2);
end

% Program sound server
A.SamplingRate = sf;
A.BpodEvents = 'On';
A.TriggerMode = 'Master';
A.loadSound(1, leftSound);
A.loadSound(2, rightSound);
A.loadSound(3, errorSound);
A.loadSound(4, earlyWithdrawalSound);
Envelope = 0.005:0.005:1; % Define envelope of amplitude coefficients, to play at sound onset + offset
A.AMenvelope = Envelope;

% Set Bpod serial message library with correct codes to trigger sounds 1-4 on analog output channels 1-2
analogPortIndex = find(strcmp(BpodSystem.Modules.Name, 'AudioPlayer1'));
if isempty(analogPortIndex)
    error('Error: Bpod AudioPlayer module not found. If you just plugged it in, please restart Bpod.')
end
LoadSerialMessages('AudioPlayer1', {['P' 0], ['P' 1], ['P' 2], ['P' 3]});

% Remember values of left and right frequencies & durations, so a new one only gets uploaded if it was changed
lastLeftFrequency = S.GUI.SinWaveFreqLeft; 
lastRightFrequency = S.GUI.SinWaveFreqRight;
lastSoundDuration = S.GUI.SoundDuration;

%% Main trial loop
for currentTrial = 1:maxTrials
    % Sync parameters with BpodParameterGUI plugin
    S = BpodParameterGUI('sync', S); 

    % Setup error sound if enabled
    if S.GUI.PunishSound
        punishOutputAction = {'AudioPlayer1', 3};
    else
        punishOutputAction = {};
    end

    % Update AudioPlayer module if tone frequency or duration was changed by the user
    if S.GUI.SinWaveFreqLeft ~= lastLeftFrequency
        leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration);
                                     % Sampling freq (hz), Sine frequency (hz), duration (s)
        A.loadSound(1, leftSound);
        lastLeftFrequency = S.GUI.SinWaveFreqLeft;
    end
    if S.GUI.SinWaveFreqRight ~= lastRightFrequency
        rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration);
        A.loadSound(2, rightSound);
        lastRightFrequency = S.GUI.SinWaveFreqRight;
    end
    if S.GUI.SoundDuration ~= lastSoundDuration
        leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration);
        rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration); 
        A.loadSound(1, leftSound); A.loadSound(2, rightSound);
        lastSoundDuration = S.GUI.SoundDuration;
    end

    % Update reward amounts
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); 
    leftValveTime = vt(1); 
    rightValveTime = vt(2);
    
    % Determine trial-specific state machine variables
    switch trialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            outputActionArgument = {'AudioPlayer1', 1, 'BNCState', 2}; 
            leftActionState = 'RewardLeft';  
            rightActionState = 'Punish';
        case 2
            outputActionArgument = {'AudioPlayer1', 2, 'BNCState', 2};
            leftActionState = 'Punish'; 
            rightActionState = 'RewardRight';
    end

    % Process training level
    if S.GUI.TrainingLevel == 1 % Reward both sides (overriding switch/case above)
        rightActionState = 'Reward'; leftActionState = 'Reward';
    end

    % Assemble state machine description
    sma = NewStateMachine(); % Initialize new state machine description
    sma = SetCondition(sma, 1, 'Port1', 0); % Condition 1: Port 1 low (is out)
    sma = SetCondition(sma, 2, 'Port3', 0); % Condition 2: Port 3 low (is out)
    sma = AddState(sma, 'Name', 'WaitForCenterPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'Delay'},...
        'OutputActions', {'AudioPlayer1','*'}); % Code to push newly uploaded waves to front (playback) buffers
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', S.GUI.StimulusDelayDuration,...
        'StateChangeConditions', {'Port2Out', 'EarlyWithdrawal', 'Tup', 'DeliverStimulus'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.SoundDuration,...
        'StateChangeConditions', {'Tup', 'WaitForResponse', 'Port2Out', 'EarlyWithdrawal'},...
        'OutputActions', outputActionArgument);
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.TimeForResponse,...
        'StateChangeConditions', {'Tup', '>exit', 'Port1In', leftActionState, 'Port3In', rightActionState},...
        'OutputActions', {'PWM1', 255, 'PWM3', 255});
    sma = AddState(sma, 'Name', 'RewardLeft', ...
        'Timer', leftValveTime,...
        'StateChangeConditions', {'Tup', 'DrinkingLeft'},...
        'OutputActions', {'ValveState', 1});
    sma = AddState(sma, 'Name', 'RewardRight', ...
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
    sma = AddState(sma, 'Name', 'Punish', ...
        'Timer', S.GUI.PunishTimeoutDuration,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', punishOutputAction);
    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', S.GUI.PunishTimeoutDuration,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {'AudioPlayer1', 4});

    % Run the trial and process data returned
    SendStateMachine(sma); % Send the state matrix to the Bpod device
    RawEvents = RunStateMachine; % Run the trial and return events
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned (i.e. if not final trial, interrupted by user)
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
        BpodSystem.Data.TrialTypes(currentTrial) = trialTypes(currentTrial); % Adds the trial type of the current trial to data
        update_outcome_plot(trialTypes, BpodSystem.Data);
        update_reward_display(S.GUI.RewardAmount, currentTrial);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0 % If protocol was stopped, exit the loop
        return
    end
end

function update_outcome_plot(trialTypes, data)
% Determine outcomes from state data and score as the SideOutcomePlot plugin expects
global BpodSystem
outcomes = zeros(1,data.nTrials);
for i = 1:data.nTrials
    if ~isnan(data.RawEvents.Trial{i}.States.RewardLeft(1))
        outcomes(i) = 1;
    elseif ~isnan(data.RawEvents.Trial{i}.States.RewardRight(1))
        outcomes(i) = 1;
    elseif ~isnan(data.RawEvents.Trial{i}.States.Punish(1))
        outcomes(i) = 0;
    else
        outcomes(i) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',data.nTrials+1,2-trialTypes,outcomes);

function update_reward_display(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
    if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.RewardLeft(1)) || ...
       ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.RewardRight(1))     
        TotalRewardDisplay('add', RewardAmount);
    end