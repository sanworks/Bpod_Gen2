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

% This protocol demonstrates a simple 2AFC task using the HiFi module to generate sound stimuli, 
% and TrialManager to achieve zero inter-trial dead time.
% Subjects initialize each trial with a poke into port 2. After a delay, a tone plays.
% If subjects exit the port before the tone is finished playing, a dissonant error sound is played.
% Subjects are rewarded for responding left (port 1) for low-pitch tones, and right (port 3) for high.
% A white noise pulse indicates incorrect choice.
% The next trial's stimulus sounds are automatically loaded to the HiFi module after the choice on each trial, 
% without interrupting any ongoing error feedback sounds.
% A TTL pulse is delivered from BNC output CH1 with the tone stimulus. This is
% useful for viewing stimulus onset latency (e.g. on an oscilloscope).
% A 1ms linear ramp envelope is applied to the stimulus at onset and offset
% (even when offset is triggered by the test subject). See 'H.AMenvelope'
% below to configure a custom envelope, or to disable it by setting to [].

function HiFiSound2AFC_TrialManager

global BpodSystem % Imports the BpodSystem object to the function workspace

%% Assert HiFi module is present + USB-paired (via USB button on console GUI)
BpodSystem.assertModule('HiFi', 1); % The second argument (1) indicates that AnalogIn must be paired with its USB serial port
% Create an instance of the HiFi module
H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1); % The argument is the name of the HiFi module's USB serial port (e.g. COM3)

%% Create trial manager object
trialManager = BpodTrialManager;

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
maxTrials = 1000;
trialTypes = ceil(rand(1,maxTrials)*2);
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


PokesPlot('init', getStateColors, getPokeColors);
useStateTiming = false;
if ~verLessThan('matlab','9.5') % StateTiming plot requires MATLAB r2018b or newer
    useStateTiming = true;
    StateTiming();
end

%% Define stimuli and send to analog module
sf = 192000; % Use max supported sampling rate
H.SamplingRate = sf;
leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration)*.9; 
                             % Sampling freq (hz), Sine frequency (hz), duration (s)
rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration)*.9;
errorSound = GenerateWhiteNoise(sf, S.GUI.ErrorDelay, 1, 2);

% Generate early withdrawal sound
w1 = GenerateSineWave(sf, 1000, .5)*.5; w2 = GenerateSineWave(sf, 1200, .5)*.5; earlyWithdrawalSound = w1+w2;
p = sf/100;
gateVector = repmat([ones(1,p) zeros(1,p)], 1, 25);
earlyWithdrawalSound = earlyWithdrawalSound.*gateVector; % Gate waveform to create aversive pulses

% Setup HiFi module
H.HeadphoneAmpEnabled = true; H.HeadphoneAmpGain = 10; % Ignored if using HD version of the HiFi module
H.DigitalAttenuation_dB = 0; % Set a negative value here if necessary for digital volume control.
H.load(1, leftSound); % Load leftSound to the HiFi module at position 1
H.load(2, rightSound); % Load rightSound to the HiFi module at position 2
H.load(3, errorSound); % Load errorSound to the HiFi module at position 3
H.load(4, earlyWithdrawalSound);
H.push; % Add newly loaded sounds to the current sound set.
% Define 1ms linear ramp envelope of amplitude coefficients, to apply at sound onset + in reverse at sound offset
Envelope = 1/(sf*0.001):1/(sf*0.001):1; 
H.AMenvelope = Envelope;

%% Prepare and start first trial
sma = PrepareStateMachine(S, trialTypes, 1, []); % Prepare state machine for trial 1 with empty "current events" variable
trialManager.startTrial(sma); % Sends & starts running first trial's state machine. A MATLAB timer object updates the 
                              % console UI, while code below proceeds in parallel.

%% Main trial loop
for currentTrial = 1:maxTrials
    % Sync parameters with BpodParameterGUI plugin
    S = BpodParameterGUI('sync', S); 
    % getCurrentEvents() Idles here until Bpod enters one of the listed trigger states, 
    % then returns current trial's states visited + events captured up to this point
    currentTrialEvents = trialManager.getCurrentEvents({'LeftReward', 'RightReward', 'TimeOutState', 'PunishTimeout', 'EarlyWithdrawal'}); 
                                       
    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 

    if currentTrial < maxTrials
        % Since PrepareStateMachine is a function with a separate workspace, pass any local variables needed to make 
        % the state machine as fields of settings struct S e.g. S.learningRate = 0.2.
        [sma, S] = PrepareStateMachine(S, trialTypes, currentTrial+1, currentTrialEvents); % Prepare next state machine.
        
        % Send the next trial's state machine description
        SendStateMachine(sma, 'RunASAP'); % With TrialManager, you can send the next trial's state machine during the trial.
        
        % Update sounds
        leftSound = GenerateSineWave(sf, S.GUI.SinWaveFreqLeft, S.GUI.SoundDuration); 
                                     % Sampling freq (hz), Sine frequency (hz), duration (s)
        rightSound = GenerateSineWave(sf, S.GUI.SinWaveFreqRight, S.GUI.SoundDuration);
        pause(rand*0.75);
        H.load(1, leftSound);
        H.load(2, rightSound);
    end
    
    % getTrialData() idles here until trial is over, then returns full trial's raw data
    RawEvents = trialManager.getTrialData;

    if BpodSystem.Status.BeingUsed == 0; return; end % If user hit console "stop" button, end session 
    
    % Check to see if the protocol is paused. If so, idle here until user resumes.
    HandlePauseCondition; 

    if currentTrial < maxTrials
        % Start processing the next trial's events (call with no argument since SM was already sent)
        trialManager.startTrial(); 
    end
    
    % Process trial data returned
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned from last trial, update plots and save data
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct 
        BpodSystem.Data.TrialTypes(currentTrial) = trialTypes(currentTrial); % Adds the trial type of the current trial to data
        PokesPlot('update'); % Update Pokes Plot
        if useStateTiming
            StateTiming();
        end
        outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
end

function [sma, S] = PrepareStateMachine(S, TrialTypes, currentTrial, currentTrialEvents)
% In this case, we don't need trial events to build the state machine - but
% they are available in currentTrialEvents.
S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
vt = GetValveTimes(S.GUI.RewardAmount, [1 3]); leftValveTime = vt(1); rightValveTime = vt(2); % Update reward amounts
switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
    case 1
        leftPokeAction = 'LeftRewardDelay'; 
        rightPokeAction = 'PunishTimeout'; 
        stimulusOutput = {'HiFi1', ['P' 0], 'BNC1', 1};
    case 2
        leftPokeAction = 'PunishTimeout'; 
        rightPokeAction = 'RightRewardDelay'; 
        stimulusOutput = {'HiFi1', ['P' 1], 'BNC1', 1};
end

% Setup state machine description
sma = NewStateMachine();
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
    'OutputActions', stimulusOutput);
sma = AddState(sma, 'Name', 'WaitForResponse', ...
    'Timer', S.GUI.ResponseTime,...
    'StateChangeConditions', {'Port1In', leftPokeAction, 'Port3In', rightPokeAction, 'Tup', 'exit'},...
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
    'Timer', 0.5,...
    'StateChangeConditions', {'Tup', 'TimeOutState', 'Port1In', '>back', 'Port3In', '>back'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'PunishTimeout', ...
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
    'DrinkingLeft',[1,0,0],...
    'DrinkingRight',[1,0,0],...
    'DrinkingGrace',[1,0.3,0],...
    'PunishTimeout',[1,0,0],...
    'CorrectEarlyWithdrawal',0.75*[0,1,1],...
    'EarlyWithdrawal',0.75*[0,1,0],...
    'TimeOutState',[1,0,0]);

function poke_colors = getPokeColors
poke_colors = struct( ...
      'L', 0.6*[1 0.66 0], ...
      'C', [0 0 0], ...
      'R',  0.9*[1 0.66 0]);