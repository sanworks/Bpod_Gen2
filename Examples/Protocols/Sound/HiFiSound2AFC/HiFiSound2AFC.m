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
function HiFiSound2AFC
% This protocol demonstrates a 2AFC task using the HiFi module to generate sound stimuli.
% Subjects initialize each trial with a poke into port 2. After a delay, a tone plays.
% If subjects exit the port before the tone is finished playing, a dissonant error sound is played.
% Subjects are rewarded for responding left for low-pitch tones, and right for high.
% A white noise pulse indicates incorrect choice.
% A TTL pulse is delivered from BNC output CH1 with the tone stimulus. This is
% useful for viewing stimulus onset latency (e.g. on an oscilloscope).
% A 1ms linear ramp envelope is applied to the stimulus at onset and offset
% (even when offset is triggered by the test subject). See 'H.AMenvelope'
% below to configure a custom envelope, or to disable it by setting to [].

global BpodSystem

%
% SETUP
% You will need:
% - A Bpod state machine v0.7+
% - A Bpod HiFi module, loaded with BpodHiFiPlayer firmware.
% - Connect the HiFi module's State Machine port to the Bpod state machine
% - From the Bpod console, pair the HiFi module with its USB serial port.
% - Connect channel 1 (or ch1+2) of the hifi module to an amplified speaker(s).

%% Assert HiFi module is present + USB-paired (via USB button on console GUI)
BpodSystem.assertModule('HiFi', 1); % The second argument (1) indicates that the HiFi module must be paired with its USB serial port
% Create an instance of the HiFi module
H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1); % The argument is the name of the HiFi module's USB serial port (e.g. COM3)

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
    S.GUI.ErrorTimeoutDuration = 2; % Seconds to wait on errors before next trial can start
    S.GUI.ErrorSound = 1; % if 1, plays a white noise pulse on error. if 0, no sound is played.
    S.GUIMeta.ErrorSound.Style = 'checkbox';
    S.GUIPanels.Task = {'TrainingLevel', 'RewardAmount', 'ErrorSound'}; % GUIPanels organize the parameters into groups.
    S.GUIPanels.Sound = {'SinWaveFreqLeft', 'SinWaveFreqRight', 'SoundDuration'};
    S.GUIPanels.Time = {'StimulusDelayDuration', 'TimeForResponse', 'ErrorTimeoutDuration'};
end

%% Define trials
MaxTrials = 5000;
TrialTypes = ceil(rand(1,MaxTrials)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
% Side Outcome Plot
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [50 540 1000 220],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .35 .89 .55]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
TotalRewardDisplay('init'); % Total Reward display (online display of the total amount of liquid reward earned)
BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% Define stimuli and send to analog module
SF = 192000; % Use max supported sampling rate
H.SamplingRate = SF;
LeftSound = GenerateSineWave(SF, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration)*.9; % Sampling freq (hz), Sine frequency (hz), duration (s)
RightSound = GenerateSineWave(SF, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration)*.9; % Sampling freq (hz), Sine frequency (hz), duration (s)
ErrorSound = GenerateWhiteNoise(SF, S.GUI.ErrorTimeoutDuration, 1, 2);

% Generate early withdrawal sound
W1 = GenerateSineWave(SF, 1000, .5)*.5; W2 = GenerateSineWave(SF, 1200, .5)*.5; EarlyWithdrawalSound = W1+W2;
P = SF/100;
GateVector = repmat([ones(1,P) zeros(1,P)], 1, 25);
EarlyWithdrawalSound = EarlyWithdrawalSound.*GateVector; % Gate waveform to create aversive pulses

H.HeadphoneAmpEnabled = true; H.HeadphoneAmpGain = 15; % Ignored if using HD version of the HiFi module
H.DigitalAttenuation_dB = -20; % Set a comfortable listening level for most headphones (useful during protocol dev).
H.load(1, LeftSound);
H.load(2, RightSound);
H.load(3, ErrorSound);
H.load(4, EarlyWithdrawalSound);
Envelope = 1/(SF*0.001):1/(SF*0.001):1; % Define 1ms linear ramp envelope of amplitude coefficients, to apply at sound onset + in reverse at sound offset
%Envelope = [];
H.AMenvelope = Envelope;

% Remember values of left and right frequencies & durations, so a new one only gets uploaded if it was changed
LastLeftFrequency = S.GUI.SinWaveFreqLeft; 
LastRightFrequency = S.GUI.SinWaveFreqRight;
LastSoundDuration = S.GUI.SoundDuration;

%% Main trial loop
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    if S.GUI.ErrorSound
        ErrorOutputAction = {'HiFi1', ['P' 2]};
    else
        ErrorOutputAction = {};
    end
    if S.GUI.SinWaveFreqLeft ~= LastLeftFrequency
        LeftSound = GenerateSineWave(SF, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
        H.load(1, [LeftSound;LeftSound]);
        LastLeftFrequency = S.GUI.SinWaveFreqLeft;
    end
    if S.GUI.SinWaveFreqRight ~= LastRightFrequency
        RightSound = GenerateSineWave(SF, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
        H.load(2, [RightSound; RightSound]);
        LastRightFrequency = S.GUI.SinWaveFreqRight;
    end
    if S.GUI.SoundDuration ~= LastSoundDuration
        LeftSound = GenerateSineWave(SF, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
        RightSound = GenerateSineWave(SF, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
        H.load(1, LeftSound); H.load(2, RightSound);
        LastSoundDuration = S.GUI.SoundDuration;
    end
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            OutputActionArgument = {'HiFi1', ['P' 0], 'BNCState', 1}; 
            LeftActionState = 'Reward';  RightActionState = 'Error'; CorrectWithdrawalEvent = 'Port1Out';
            ValveCode = 1; ValveTime = LeftValveTime;
        case 2
            OutputActionArgument = {'HiFi1', ['P' 1], 'BNCState', 1};
            LeftActionState = 'Error'; RightActionState = 'Reward'; CorrectWithdrawalEvent = 'Port3Out';
            ValveCode = 4; ValveTime = RightValveTime;
    end
    if S.GUI.TrainingLevel == 1 % Reward both sides (overriding switch/case above)
        RightActionState = 'Reward'; LeftActionState = 'Reward';
    end
    sma = NewStateMatrix(); % Assemble state matrix
    sma = SetCondition(sma, 1, 'Port1', 0); % Condition 1: Port 1 low (is out)
    sma = SetCondition(sma, 2, 'Port3', 0); % Condition 2: Port 3 low (is out)
    sma = AddState(sma, 'Name', 'WaitForCenterPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'Delay'},...
        'OutputActions', {'HiFi1','*'}); % Code to push newly uploaded waves to front (playback) buffers
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', S.GUI.StimulusDelayDuration,...
        'StateChangeConditions', {'Port2Out', 'EarlyWithdrawal', 'Tup', 'DeliverStimulus'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.SoundDuration,...
        'StateChangeConditions', {'Tup', 'WaitForResponse', 'Port2Out', 'ResetBNC'},...
        'OutputActions', OutputActionArgument);
    sma = AddState(sma, 'Name', 'ResetBNC', ...
        'Timer', 0.001,...
        'StateChangeConditions', {'Tup', 'EarlyWithdrawal'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.TimeForResponse,...
        'StateChangeConditions', {'Tup', '>exit', 'Port1In', LeftActionState, 'Port3In', RightActionState},...
        'OutputActions', {'PWM1', 255, 'PWM3', 255});
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'ValveState', ValveCode});
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', 0,...
        'StateChangeConditions', {'Condition1', 'DrinkingGrace', 'Condition2', 'DrinkingGrace'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'DrinkingGrace', ...
        'Timer', 0.5,...
        'StateChangeConditions', {'Tup', '>exit', 'Port1In', 'Drinking', 'Port3In', 'Drinking'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Error', ...
        'Timer', S.GUI.ErrorTimeoutDuration,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', ErrorOutputAction);
    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', S.GUI.ErrorTimeoutDuration,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {'HiFi1', ['P' 3], 'BNCState', 1});
    SendStateMachine(sma); % Send the state matrix to the Bpod device
    RawEvents = RunStateMachine; % Run the trial and return events
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned (i.e. if not final trial, interrupted by user)
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0 % If protocol was stopped, exit the loop
        return
    end
end

function UpdateSideOutcomePlot(TrialTypes, Data)
% Determine outcomes from state data and score as the SideOutcomePlot plugin expects
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Error(1))
        Outcomes(x) = 0;
    else
        Outcomes(x) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);

function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
    if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
        TotalRewardDisplay('add', RewardAmount);
    end