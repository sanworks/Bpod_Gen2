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

% This protocol demonstrates a simple 2AFC task using the HiFi module to generate sound stimuli, and TrialManager to achieve zero inter-trial dead time.
% Subjects initialize each trial with a poke into port 2. After a delay, a tone plays.
% If subjects exit the port before the tone is finished playing, a dissonant error sound is played.
% Subjects are rewarded for responding left (port 1) for low-pitch tones, and right (port 3) for high.
% A white noise pulse indicates incorrect choice.
% The next trial's stimulus sounds are automatically loaded to the HiFi module after the choice on each trial, without interrupting any ongoing error feedback sounds.
% A TTL pulse is delivered from BNC output CH1 with the tone stimulus. This is
% useful for viewing stimulus onset latency (e.g. on an oscilloscope).
% A 1ms linear ramp envelope is applied to the stimulus at onset and offset
% (even when offset is triggered by the test subject). See 'H.AMenvelope'
% below to configure a custom envelope, or to disable it by setting to [].

function HiFiSound2AFC_TrialManager

global BpodSystem

%% Assert HiFi module is present + USB-paired (via USB button on console GUI)
BpodSystem.assertModule('HiFi', 1); % The second argument (1) indicates that AnalogIn must be paired with its USB serial port
% Create an instance of the HiFi module
H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1); % The argument is the name of the HiFi module's USB serial port (e.g. COM3)

%% Create trial manager object
TrialManager = BpodTrialManager;

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %ul
    S.GUI.SoundDuration = 0.5; % Duration of sound (s)
    S.GUI.SinWaveFreqLeft = 500; % Frequency of left cue
    S.GUI.SinWaveFreqRight = 2000; % Frequency of right cue
    S.GUI.CueDelay = 0; % How long the mouse must poke in the center to activate the sound
    S.GUI.ResponseTime = 5; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.RewardDelay = 0; % How long the mouse must wait in the goal port for reward to be delivered
    S.GUI.ErrorSound = 1; % if 1, plays a white noise pulse on error. if 0, no sound is played.
    S.GUI.ErrorDelay = 3; %% How long the mouse must wait to start the next trial if it makes the wrong choice (s)
    S.GUIPanels.Task = {'RewardAmount', 'ErrorSound'}; % GUIPanels organize the parameters into groups.
    S.GUIPanels.Sound = {'SinWaveFreqLeft', 'SinWaveFreqRight', 'SoundDuration'};
    S.GUIPanels.Time = {'CueDelay', 'RewardDelay', 'ResponseTime', 'ErrorDelay'};
end

%% Define trial types
MaxTrials = 1000;
TrialTypes = ceil(rand(1,MaxTrials)*2);
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [50 540 1000 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .35 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);
BpodNotebook('init');
BpodParameterGUI('init', S); % Initialize parameter GUI plugin   
PokesPlot('init', getStateColors, getPokeColors);
useStateTiming = false;
if ~verLessThan('matlab','9.5') % StateTiming plot requires MATLAB r2018b or newer
    useStateTiming = true;
    StateTiming();
end

%% Define stimuli and send to analog module
SF = 192000; % Use max supported sampling rate
H.SamplingRate = SF;
LeftSound = GenerateSineWave(SF, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration)*.9; % Sampling freq (hz), Sine frequency (hz), duration (s)
RightSound = GenerateSineWave(SF, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration)*.9; % Sampling freq (hz), Sine frequency (hz), duration (s)
ErrorSound = GenerateWhiteNoise(SF, S.GUI.ErrorDelay, 1, 2);

% Generate early withdrawal sound
W1 = GenerateSineWave(SF, 1000, .5)*.5; W2 = GenerateSineWave(SF, 1200, .5)*.5; EarlyWithdrawalSound = W1+W2;
P = SF/100;
GateVector = repmat([ones(1,P) zeros(1,P)], 1, 25);
EarlyWithdrawalSound = EarlyWithdrawalSound.*GateVector; % Gate waveform to create aversive pulses

% Program sound server
% A.BpodEvents = 'On';
% A.TriggerMode = 'Master';
H.HeadphoneAmpEnabled = true; H.HeadphoneAmpGain = 30; % Ignored if using HD version of the HiFi module
H.DigitalAttenuation_dB = -10; % Set a comfortable listening level for most headphones (useful during protocol dev).
H.load(1, LeftSound);
H.load(2, [RightSound; RightSound]);
H.load(3, ErrorSound);
H.load(4, EarlyWithdrawalSound);
H.push;
Envelope = 1/(SF*0.001):1/(SF*0.001):1; % Define 1ms linear ramp envelope of amplitude coefficients, to apply at sound onset + in reverse at sound offset
H.AMenvelope = Envelope;

%% Prepare and start first trial
sma = PrepareStateMachine(S, TrialTypes, 1, []); % Prepare state machine for trial 1 with empty "current events" variable
TrialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.

%% Main trial loop
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    currentTrialEvents = TrialManager.getCurrentEvents({'LeftReward', 'RightReward', 'TimeOutState', 'Error', 'EarlyWithdrawal'}); 
                                       % Hangs here until Bpod enters one of the listed trigger states, 
                                       % then returns current trial's states visited + events captured to this point
    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
    [sma, S] = PrepareStateMachine(S, TrialTypes, currentTrial+1, currentTrialEvents); % Prepare next state machine.
    % Since PrepareStateMachine is a function with a separate workspace, pass any local variables needed to make 
    % the state machine as fields of settings struct S e.g. S.learningRate = 0.2.
    SendStateMachine(sma, 'RunASAP'); % With TrialManager, you can send the next trial's state machine while the current trial is ongoing
    % Update sounds
    LeftSound = GenerateSineWave(SF, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
    RightSound = GenerateSineWave(SF, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
    pause(rand*0.75);
    H.load(1, LeftSound);
    H.load(2, RightSound);
    RawEvents = TrialManager.getTrialData; % Hangs here until trial is over, then retrieves full trial's raw data
    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    TrialManager.startTrial(); % Start processing the next trial's events (call with no argument since SM was already sent)
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned from last trial, update plots and save data
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        PokesPlot('update'); % Update Pokes Plot
        if useStateTiming
            StateTiming();
        end
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data); % Update side outcome plot
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
end

function [sma, S] = PrepareStateMachine(S, TrialTypes, currentTrial, currentTrialEvents)
% In this case, we don't need trial events to build the state machine - but
% they are available in currentTrialEvents.
S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
R = GetValveTimes(S.GUI.RewardAmount, [1 3]); LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
    case 1
        LeftPokeAction = 'LeftRewardDelay'; RightPokeAction = 'Error'; StimulusOutput = {'HiFi1', ['P' 0], 'BNC1', 1};
    case 2
        LeftPokeAction = 'Error'; RightPokeAction = 'RightRewardDelay'; StimulusOutput = {'HiFi1', ['P' 1], 'BNC1', 1};
end
sma = NewStateMachine(); % Assemble state machine description
sma = SetCondition(sma, 1, 'Port1', 0); % Condition 1: Port 1 low (is out)
sma = SetCondition(sma, 2, 'Port3', 0); % Condition 2: Port 3 low (is out)
sma = AddState(sma, 'Name', 'WaitForPoke', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port2In', 'CueDelay'},...
    'OutputActions', {'HiFi1', '*', 'LED', 2}); % Serial message #6 = 'Push' command, to make any newly loaded sounds current
sma = AddState(sma, 'Name', 'CueDelay', ...
    'Timer', S.GUI.CueDelay,...
    'StateChangeConditions', {'Port2Out', 'EarlyWithdrawal', 'Tup', 'DeliverStimulus'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'DeliverStimulus', ...
    'Timer', S.GUI.SoundDuration,...
    'StateChangeConditions', {'Port2Out', 'EarlyWithdrawal', 'Tup', 'WaitForResponse'},...
    'OutputActions', StimulusOutput);
sma = AddState(sma, 'Name', 'WaitForResponse', ...
    'Timer', S.GUI.ResponseTime,...
    'StateChangeConditions', {'Port1In', LeftPokeAction, 'Port3In', RightPokeAction, 'Tup', 'TimeOutState'},...
    'OutputActions', {}); 
sma = AddState(sma, 'Name', 'LeftRewardDelay', ...
    'Timer', S.GUI.RewardDelay,...
    'StateChangeConditions', {'Tup', 'LeftReward', 'Port1Out', 'CorrectEarlyWithdrawal'},...
    'OutputActions', {}); 
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
    'StateChangeConditions', {'Condition1', 'DrinkingGrace', 'Condition2', 'DrinkingGrace'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'DrinkingGrace', ...
    'Timer', 0.5,...
    'StateChangeConditions', {'Tup', 'TimeOutState', 'Port1In', 'Drinking', 'Port3In', 'Drinking'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'Error', ...
    'Timer', S.GUI.ErrorDelay,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'HiFi1', ['P' 2]});
sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
    'Timer', S.GUI.ErrorDelay,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'HiFi1', ['P' 3]});
sma = AddState(sma, 'Name', 'CorrectEarlyWithdrawal', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'TimeOutState'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'TimeOutState', ... % Record events while next trial's state machine is sent
    'Timer', 1,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {});

function UpdateSideOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Drinking(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Error(1))
        Outcomes(x) = 0;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.CorrectEarlyWithdrawal(1))
        Outcomes(x) = 2;
    else
        Outcomes(x) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);

function state_colors = getStateColors
state_colors = struct( ...
    'WaitForPoke', [0.5 0.5 1],...
    'CueDelay',0.3*[1 1 1],...
    'DeliverStimulus', 0.75*[1 1 0],...
    'WaitForResponse',[0.5 1 1],... 
    'LeftRewardDelay',[.2,.2,1],...
    'RightRewardDelay',[.7,.7,1],...
    'LeftReward',[0,1,0],...
    'RightReward',[0,0,1],...
    'Drinking',[1,0,0],...
    'DrinkingGrace',[1,0.3,0],...
    'Error',[1,0,0],...
    'CorrectEarlyWithdrawal',0.75*[0,1,1],...
    'EarlyWithdrawal',0.75*[0,1,0],...
    'TimeOutState',[1,0,0]);

function poke_colors = getPokeColors
poke_colors = struct( ...
      'L', 0.6*[1 0.66 0], ...
      'C', [0 0 0], ...
      'R',  0.9*[1 0.66 0]);