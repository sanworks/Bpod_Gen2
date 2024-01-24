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

% This protocol demonstrates a 2AFC task using the HiFi module's synth features to generate sound stimuli.
% Subjects initialize each trial with a poke into port 2. After a delay, a tone plays.
% If subjects exit the port before the tone is finished playing, a white noise pulse train is played.
% Subjects are rewarded for responding left for low-pitch tones, and right for high.
% A long white noise pulse indicates incorrect choice.
% A TTL pulse is delivered from BNC output CH1 with the tone stimulus. This is
% useful for viewing stimulus onset latency (e.g. on an oscilloscope).
% A 1ms linear ramp envelope is applied to the stimulus at onset and offset
% (even when offset is triggered by the test subject). See 'H.SynthAmplitudeFade'
% below to configure a custom envelope duration, or to disable it by setting to 0.

% SETUP
% You will need:
% - A Bpod state machine v0.7+
% - A Bpod HiFi module, loaded with BpodHiFiPlayer firmware.
% - Connect the HiFi module's State Machine port to the Bpod state machine
% - From the Bpod console, pair the HiFi module with its USB serial port.
% - Connect channel 1 (or ch1+2) of the hifi module to an amplified speaker(s).

function HiFiSound2AFC_Synth

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
    S.GUI.AmplitudeRamp_ms = 2;
    S.GUI.RewardAmount = 5; % in ul
    S.GUI.StimulusDelayDuration = 0; % Seconds before stimulus plays on each trial
    S.GUI.TimeForResponse = 5; % Seconds after stimulus sampling for a response
    S.GUI.EarlyWithdrawalTimeout = 0.5; % Seconds to wait on early withdrawal before next trial can start
    S.GUI.ErrorTimeoutDuration = 2; % Seconds to wait on errors before next trial can start
    S.GUI.ErrorSound = 1; % if 1, plays a white noise pulse on error. if 0, no sound is played.
    S.GUI.InterTrialInterval = 0; % Extra delay between trials (adds to inter-trial dead-time)
    S.GUIMeta.ErrorSound.Style = 'checkbox';
    % GUIPanels organize the parameters into groups.
    S.GUIPanels.Task = {'TrainingLevel', 'RewardAmount', 'ErrorSound', 'InterTrialInterval'}; 
    S.GUIPanels.Sound = {'SinWaveFreqLeft', 'SinWaveFreqRight', 'SoundDuration', 'AmplitudeRamp_ms'};
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

%% Setup HiFi module
maxAmplitude_Bits = 32767;
sf = 192000; % Use max supported sampling rate
H.SamplingRate = sf;
H.HeadphoneAmpEnabled = true; H.HeadphoneAmpGain = 10; % Ignored if using HD version of the HiFi module
H.DigitalAttenuation_dB = 0; % Set a negative value here if necessary for digital volume control.
H.SynthAmplitude = 0;
soundOnBytes = ['N' typecast(uint16(maxAmplitude_Bits), 'uint8')];
soundOffBytes = ['N' typecast(uint16(0), 'uint8')];

%% Main trial loop
for currentTrial = 1:maxTrials
    % Sync parameters with BpodParameterGUI plugin
    S = BpodParameterGUI('sync', S); 

    % Setup error sound if enabled
    if S.GUI.ErrorSound
        errorOutputAction = {'HiFi1', soundOnBytes}; % ['N' X X] where X X are bytes of the 16-bit synth waveform amplitude
    else
        errorOutputAction = {'HiFi1', soundOffBytes};
    end
    
    % Update GUI parameters
    H.SynthAmplitudeFade = (sf/1000)*S.GUI.AmplitudeRamp_ms; % number of samples for amplitude transitions
    vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); leftValveTime = vt(1); rightValveTime = vt(2); % Update reward amounts

    % Determine trial-specific state machine variables
    switch trialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            % Frequency*1000 is sent to the device to encode Frequency
            frequencyBytes = typecast(uint32(S.GUI.SinWaveFreqLeft*1000), 'uint8'); 
            leftActionState = 'RewardLeft';  
            rightActionState = 'PunishSetup'; 
        case 2
            frequencyBytes = typecast(uint32(S.GUI.SinWaveFreqRight*1000), 'uint8');
            leftActionState = 'PunishSetup'; 
            rightActionState = 'RewardRight';
    end
    outputActionArgument1 = {'HiFi1', ['F' frequencyBytes(1:2)]}; 
    outputActionArgument2 = {'HiFi1', [frequencyBytes(3:4)], 'BNCState', 1}; 

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
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', S.GUI.StimulusDelayDuration,...
        'StateChangeConditions', {'Port2Out', 'EarlyWithdrawalSetup', 'Tup', 'SetWaveformFrequency1'},...
        'OutputActions', {'HiFi1',['W' 1]}); % Select sine waveform
    sma = AddState(sma, 'Name', 'SetWaveformFrequency1', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'SetWaveformFrequency2'},...
        'OutputActions', outputActionArgument1);
    sma = AddState(sma, 'Name', 'SetWaveformFrequency2', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'DeliverStimulus'},...
        'OutputActions', outputActionArgument2);
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.SoundDuration,...
        'StateChangeConditions', {'Tup', 'WaitForResponse', 'Port2Out', 'EarlyWithdrawalSetup'},...
        'OutputActions', {'HiFi1', soundOnBytes});
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.TimeForResponse,...
        'StateChangeConditions', {'Tup', 'ITI', 'Port1In', leftActionState, 'Port3In', rightActionState},...
        'OutputActions', {'PWM1', 255, 'PWM3', 255, 'HiFi1', soundOffBytes});
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
        'StateChangeConditions', {'Tup', 'ITI', 'Port1In', '>back', 'Port3In', '>back'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'PunishSetup', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'PunishTimeout'},...
        'OutputActions', {'HiFi1',['W' 0]}); % Set white noise waveform
    sma = AddState(sma, 'Name', 'PunishTimeout', ...
        'Timer', S.GUI.ErrorTimeoutDuration,...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', errorOutputAction);
    sma = AddState(sma, 'Name', 'EarlyWithdrawalSetup', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'EarlyWithdrawal'},...
        'OutputActions', {'HiFi1',['W' 0]}); % Set white noise waveform
    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', S.GUI.EarlyWithdrawalTimeout,...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', {'HiFi1', soundOnBytes});
    sma = AddState(sma, 'Name', 'ITI', ...
        'Timer', S.GUI.InterTrialInterval,...
        'StateChangeConditions', {'Tup', '>exit'},...
        'OutputActions', {'HiFi1', soundOffBytes});

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
