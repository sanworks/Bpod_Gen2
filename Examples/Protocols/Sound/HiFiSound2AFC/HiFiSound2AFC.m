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

% SETUP
% You will need:
% - A Bpod state machine v0.7 or newer
% - A Bpod HiFi module, loaded with BpodHiFiPlayer firmware.
% - Connect the HiFi module's State Machine port to the Bpod state machine
% - From the Bpod console, pair the HiFi module with its USB serial port.
% - Connect channel 1 (or ch1+2) of the hifi module to an amplified speaker(s).

function HiFiSound2AFC

global BpodSystem % Imports the BpodSystem object to the function workspace

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
outcomePlot.RewardStateNames = {'RewardLeft', 'RewardRight'}; % List of state names where reward was delivered
outcomePlot.PunishStateNames = {'PunishTimeout'}; % List of state names where choice was incorrect and negatively reinforced

% Total Reward display (online display of the total amount of liquid reward earned)
TotalRewardDisplay('init'); 

% Initialize parameter GUI plugin
BpodParameterGUI('init', S); 

%% Define stimuli and send to sound module
sf = 192000; % Use max supported sampling rate
H.SamplingRate = sf;
leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration)*.9; 
                             % Sampling freq (hz), Sine frequency (hz), duration (s)
rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration)*.9;
errorSound = GenerateWhiteNoise(sf, S.GUI.ErrorTimeoutDuration, 1, 2);

% Generate early withdrawal sound
w1 = GenerateSineWave(sf, 1000, .5)*.5; w2 = GenerateSineWave(sf, 1200, .5)*.5; earlyWithdrawalSound = w1+w2;
p = sf/100;
gateVector = repmat([ones(1,p) zeros(1,p)], 1, 25);
earlyWithdrawalSound = earlyWithdrawalSound.*gateVector; % Gate waveform to create aversive pulses

% Setup HiFi module
H.HeadphoneAmpEnabled = true; H.HeadphoneAmpGain = 10; % Ignored if using HD version of the HiFi module
H.DigitalAttenuation_dB = 0; % Set a negative value here if necessary for digital volume control.
H.load(1, leftSound);
H.load(2, rightSound);
H.load(3, errorSound);
H.load(4, earlyWithdrawalSound);

% Define 1ms linear ramp envelope of amplitude coefficients, to apply at sound onset + in reverse at sound offset
envelope = 1/(sf*0.001):1/(sf*0.001):1; 
H.AMenvelope = envelope;

% Remember values of left and right frequencies & durations, so a new one only gets uploaded if it was changed
lastLeftFrequency = S.GUI.SinWaveFreqLeft; 
lastRightFrequency = S.GUI.SinWaveFreqRight;
lastSoundDuration = S.GUI.SoundDuration;

%% Main trial loop
for currentTrial = 1:maxTrials
    % Sync parameters with BpodParameterGUI plugin
    S = BpodParameterGUI('sync', S); 

    % Setup error sound if enabled
    if S.GUI.ErrorSound
        errorOutputAction = {'HiFi1', ['P' 2]};
    else
        errorOutputAction = {};
    end

    % Update HiFi module if tone frequency or duration was changed by the user
    if S.GUI.SinWaveFreqLeft ~= lastLeftFrequency
        leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration); 
                                     % Sampling freq (hz), Sine frequency (hz), duration (s)
        H.load(1, [leftSound;leftSound]);
        lastLeftFrequency = S.GUI.SinWaveFreqLeft;
    end
    if S.GUI.SinWaveFreqRight ~= lastRightFrequency
        rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration);
        H.load(2, [rightSound; rightSound]);
        lastRightFrequency = S.GUI.SinWaveFreqRight;
    end
    if S.GUI.SoundDuration ~= lastSoundDuration
        leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration);
        rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration);
        H.load(1, leftSound); H.load(2, rightSound);
        lastSoundDuration = S.GUI.SoundDuration;
    end

    % Update reward amounts
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); leftValveTime = vt(1); rightValveTime = vt(2); 

    % Determine trial-specific state machine variables
    switch trialTypes(currentTrial) 
        case 1
            outputActionArgument = {'HiFi1', ['P' 0], 'BNCState', 1}; 
            leftActionState = 'RewardLeft';  
            rightActionState = 'PunishTimeout';
        case 2
            outputActionArgument = {'HiFi1', ['P' 1], 'BNCState', 1};
            leftActionState = 'PunishTimeout'; 
            rightActionState = 'RewardRight';
    end
    
    % Process training level
    if S.GUI.TrainingLevel == 1 % Reward both sides (overriding switch/case above)
        rightActionState = 'RewardRight'; leftActionState = 'RewardLeft';
    end

    % Assemble state machine description
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
        'OutputActions', outputActionArgument);
    sma = AddState(sma, 'Name', 'ResetBNC', ...
        'Timer', 0.001,...
        'StateChangeConditions', {'Tup', 'EarlyWithdrawal'},...
        'OutputActions', {});
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
    sma = AddState(sma, 'Name', 'PunishTimeout', ...
        'Timer', S.GUI.ErrorTimeoutDuration,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', errorOutputAction);
    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', S.GUI.ErrorTimeoutDuration,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {'HiFi1', ['P' 3], 'BNCState', 1});

    % Run the trial and process data returned
    SendStateMachine(sma); % Send the state matrix to the Bpod device
    RawEvents = RunStateMachine; % Run the trial and return events
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned (i.e. if not final trial, interrupted by user)
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
        BpodSystem.Data.TrialTypes(currentTrial) = trialTypes(currentTrial); % Adds the trial type of the current trial to data
        outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot
        if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.RewardLeft(1)) || ...
           ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.RewardRight(1))     
            TotalRewardDisplay('add', S.GUI.RewardAmount);
        end
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0 % If protocol was stopped, exit the loop
        return
    end
end
