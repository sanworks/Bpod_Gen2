function ToneClouds4BPod

% This protocol implements ToneClouds (developed by P. Znamenskiy) on Bpod
% Based on PsychoToolboxSound (written by J.Sanders)

% Written by F.Carnevale, 2/2015.
% Modified by J. Sanders 3/2016.

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    % Stimulation Parameters
    S.GUI.UseStimulation = 0;
    S.GUIMeta.UseStimulation.Style = 'checkbox';
    S.GUI.TrainDelay = 0.008;
    S.GUI.PulseWidth = 0.001;
    S.GUI.PulseInterval = 0.1;
    S.GUI.StimProbability = 1;
    S.GUIPanels.Stimulation = {'UseStimulation', 'TrainDelay', 'PulseWidth', 'PulseInterval', 'StimProbability'};
    
    % Protocol parameters
    % 1. Define parameters and values (with legacy syntax)
    S.GUI.Subject = BpodSystem.GUIData.SubjectName;
    S.GUI.Stage = 3;
    % 2. Parameter types and meta-data (assumes "edit" style if no meta info is specified)
    S.GUIMeta.Stage.Style = 'popupmenu';
    S.GUIMeta.Stage.String = {'Direct', 'NextCorrectPoke', 'OnlyCorrectPoke'};
    % Assigns each parameter to a panel on the GUI (assumes "Parameters" panel if not specified)
    S.GUIPanels.Protocol = {'Subject', 'Stage'};
    
    % Stimulus parameters
    S.GUI.UseMiddleOctave = 1;
    S.GUI.DifficultyLow = 1;
    S.GUI.DifficultyHigh = 1;
    S.GUI.nDifficulties = 0;
    S.GUI.ToneOverlap = 0;
    S.GUI.ToneDuration = 0.03;
    S.GUI.SoundMaxDuration = 1;
    S.GUI.NoEvidence = 0;
    S.GUI.AudibleHuman = 1;
    S.GUI.UseMiddleOctave = 1;
    S.GUIMeta.UseMiddleOctave.Style = 'popupmenu';
    S.GUIMeta.UseMiddleOctave.String = {'no', 'yes'};
    S.GUIMeta.AudibleHuman.Style = 'checkbox';
    S.GUIPanels.StimulusSettings = {'UseMiddleOctave', 'DifficultyLow', 'DifficultyHigh', 'nDifficulties'...
        'ToneOverlap', 'ToneDuration', 'SoundMaxDuration', 'NoEvidence', 'AudibleHuman'};
    
    % Reward parameters
    S.GUI.RewardAmount = 2.5;
    S.GUI.PunishSound = 1;
    S.GUI.FreqSide = 1;
    S.GUIMeta.FreqSide.Style = 'popupmenu';
    S.GUIMeta.FreqSide.String = {'LowLeft', 'LowRight'};
    S.GUIMeta.PunishSound.Style = 'checkbox';
    S.GUIPanels.RewardSettings = {'RewardAmount', 'FreqSide', 'PunishSound'};

    % Trial structure 
    S.GUI.TimeForResponse = 10;
    S.GUI.TimeForReversal = 5;
    S.GUI.TimeoutDuration = 4;
    S.GUIPanels.TrialStructure = {'TimeForResponse', 'TimeForReversal', 'TimeoutDuration'};
    
    % Prestimulus delay
    S.GUI.PrestimDistribution = 1;
    S.GUIMeta.PrestimDistribution.Style = 'popupmenu';
    S.GUIMeta.PrestimDistribution.String = {'Delta', 'Uniform', 'Exponential'};
    S.GUI.PrestimDurationStart = 0.050;
    S.GUI.PrestimDurationEnd = 0.050;
    S.GUI.PrestimDurationStep = 0.050;
    S.GUI.PrestimDurationNtrials = 50;
    S.GUI.PrestimDurationCurrent = S.GUI.PrestimDurationStart;
    S.GUIMeta.PrestimDurationCurrent.Style = 'text';
    S.GUIPanels.PrestimulusDelay = {'PrestimDistribution', 'PrestimDurationStart', 'PrestimDurationEnd',...
        'PrestimDurationStep', 'PrestimDurationNtrials', 'PrestimDurationCurrent'};
    
    % Antibias
    S.GUI.Antibias = 1;
    S.GUIMeta.Antibias.Style = 'popupmenu';
    S.GUIMeta.Antibias.String = {'no', 'yes'};
    S.GUIPanels.Antibias = {'Antibias'};
    
end
% Set frequency range
if S.GUI.AudibleHuman
    minFreq = 2000; maxFreq = 10000; 
else
    minFreq = 5000; maxFreq = 40000; 
end
% Blank Pulse Pal Parameters
S.InitialPulsePalParameters = struct;
% Other Stimulus settings (not in the GUI)
StimulusSettings.ToneOverlap = S.GUI.ToneOverlap;
StimulusSettings.ToneDuration = S.GUI.ToneDuration;
StimulusSettings.minFreq = minFreq;
StimulusSettings.maxFreq = maxFreq;
StimulusSettings.SamplingRate = 192000; % Sound card sampling rate;
StimulusSettings.UseMiddleOctave = S.GUIMeta.UseMiddleOctave(S.GUI.UseMiddleOctave);
StimulusSettings.Noevidence = S.GUI.NoEvidence;   
StimulusSettings.nFreq = 18; % Number of different frequencies to sample from
StimulusSettings.ramp = 0.005;    
StimulusSettings.Volume = 60;

%% Define trials
MaxTrials = 5000;
TrialTypes = ceil(rand(1,MaxTrials)*2); % correct side for each trial
EvidenceStrength = nan(1,MaxTrials); % evidence strength for each trial
PrestimDuration = nan(1,MaxTrials); % prestimulation delay period for each trial
Outcomes = nan(1,MaxTrials);
StimulationTrials = zeros(1,MaxTrials);
AccumulatedReward=0;

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
BpodSystem.Data.EvidenceStrength = []; % The evidence strength of each trial completed will be added here.
BpodSystem.Data.PrestimDuration = []; % The evidence strength of each trial completed will be added here.
BpodSystem.Data.StimulationTrials = [];

%% Initialize plots

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

% Outcome plot
BpodSystem.ProtocolFigures.OutcomePlotFig = figure('Position', [50 50 1000 163],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.OutcomePlot = axes('Position', [.075 .3 .89 .6]);
OutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'init',2-TrialTypes);

% Notebook
%BpodNotebook('init');

% Performance
% PerformancePlot(BpodSystem.GUIHandles.PerformancePlot,'init'); 
SlidingWindowSize = 30; % Size of sliding window average, units = trials
TrialGroups{1} = [1]; TrialGroups{2} = [2]; % Groups of trial types to plot %correct
TrialGroupNames{1} = 'Left'; TrialGroupNames{2} = 'Right'; % Names of consecutive groups
PerformancePlot('init', TrialGroups, TrialGroupNames, SlidingWindowSize);

% Psychometric
BpodSystem.ProtocolFigures.PsychoPlotFig = figure('Position', [50 50 400 300],'name','Pshycometric plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.PsychoPlot = axes('Position', [.2 .25 .75 .65]);
PsychoPlot(BpodSystem.GUIHandles.PsychoPlot,'init'); 

% Stimulus plot
%BpodSystem.ProtocolFigures.StimulusPlotFig = figure('Position', [50 50 500 300],'name','Stimulus plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
%BpodSystem.GUIHandles.StimulusPlot = axes('Position', [.15 .2 .75 .65]);
%StimulusPlot(BpodSystem.GUIHandles.StimulusPlot,'init',StimulusSettings.nFreq);

%%% Pokes plot
state_colors = struct( ...
    'WaitForCenterPoke', [0.5 0.5 1],...
    'Delay',0.3*[1 1 1],...
    'DeliverStimulus', 0.75*[1 1 0],...
    'GoSignal',[0.5 1 1],... 
    'WaitForLeftPoke',[.2,.2,1],...
    'WaitForRightPoke',[.7,.7,1],...
    'Reward',[0,1,0],...
    'Drinking',[0,0,1],...
    'Punish',[1,0,0],...
    'EarlyWithdrawal',[1,0.3,0],...
    'EarlyWithdrawalPunish',[1,0,0],...
    'WaitForResponse',0.75*[0,1,1],...
    'CorrectWithdrawalEvent',[1,0,0],...
    'exit',0.2*[1 1 1]);
    
poke_colors = struct( ...
      'L', 0.6*[1 0.66 0], ...
      'C', [0 0 0], ...
      'R',  0.9*[1 0.66 0]);
    
PokesPlot('init', state_colors, poke_colors);


%% Define stimuli and send to sound server

SF = StimulusSettings.SamplingRate;
AttenuationFactor = .5;
PunishSound = (rand(1,SF*.5)*AttenuationFactor) - AttenuationFactor*.5;

% Program sound server
PsychToolboxSoundServer('init')
PsychToolboxSoundServer('Load', 2, 0);
PsychToolboxSoundServer('Load', 3, PunishSound);

% Set soft code handler to trigger sounds
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlaySound';

BpodSystem.ProtocolFigures.InitialMsg = msgbox({'', ' Edit your settings and click OK when you are ready to start!     ', ''},'ToneCloud Protocol...');

uiwait(BpodSystem.ProtocolFigures.InitialMsg);
S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
UsingStimulation = 0;
if S.GUI.UseStimulation
    PulsePal;
    load TC4B_PulsePalProgram;
    ProgramPulsePal(ParameterMatrix);
    S.InitialPulsePalParameters = ParameterMatrix;
    UsingStimulation = 1;
end
% Set timer for this session
SessionBirthdate = tic;

% Control the step up of prestimulus period and stimulus duration
controlStep_Prestim = 0; % valid trial counter
tic
%% Main trial loop
for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    if S.GUI.UseStimulation
        StimulationTrials(currentTrial) = rand < S.GUI.StimProbability;
        if (~UsingStimulation)
            PulsePal;
            load TC4B_PulsePalProgram;
            ProgramPulsePal(ParameterMatrix);
            S.InitialPulsePalParameters = ParameterMatrix;
            UsingStimulation = 1;
        end  
        ProgramPulsePalParam(1, 'Phase1Duration', S.GUI.PulseWidth);
        ProgramPulsePalParam(1, 'InterPulseInterval', S.GUI.PulseInterval);
        ProgramPulsePalParam(1, 'PulseTrainDelay', S.GUI.TrainDelay);
        if StimulationTrials(currentTrial)
            ProgramPulsePalParam(1,'LinkTriggerChannel1', 1);
        else
            ProgramPulsePalParam(1,'LinkTriggerChannel1', 0);
        end
    else
        if UsingStimulation
            ProgramPulsePalParam(1,'LinkTriggerChannel1', 0);
            UsingStimulation = 0;
        end
        StimulationTrials(currentTrial) = 0;
    end
    if S.GUI.AudibleHuman, minFreq = 200; maxFreq = 2000; else minFreq = 5000; maxFreq = 40000; end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Prestimulation Duration
    
    if currentTrial==1 %start from the start
        S.GUI.PrestimDurationCurrent =  S.GUI.PrestimDurationStart;
    end
    
    controlStep_nRequiredValid_Prestim = S.GUI.PrestimDurationNtrials;
    
    if S.GUI.PrestimDurationStart<S.GUI.PrestimDurationEnd %step up prestim duration only if start<end
        if controlStep_Prestim > controlStep_nRequiredValid_Prestim

            controlStep_Prestim = 0; %restart counter

            % step up, unless we are at the max
            if S.GUI.PrestimDurationCurrent + S.GUI.PrestimDurationStep > S.GUI.PrestimDurationEnd
                S.GUI.PrestimDurationCurrent = S.GUI.PrestimDurationEnd;
            else
                S.GUI.PrestimDurationCurrent = S.GUI.PrestimDurationCurrent + S.GUI.PrestimDurationStep;
            end
        end
    else
       S.GUI.PrestimDurationCurrent =  S.GUI.PrestimDurationStart;
    end    
    
    
    switch S.GUI.PrestimDistribution
        case 1
            PrestimDuration(currentTrial) = S.GUI.PrestimDurationCurrent;
        case 2'
            PrestimDuration(currentTrial) = rand+S.GUI.PrestimDurationCurrent-0.5;
        case 3
            PrestimDuration(currentTrial) = exprnd(S.GUI.PrestimDurationCurrent);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    

    R = BpodLiquidCalibration('GetValveTimes', S.GUI.RewardAmount, [1 3]); % Update reward amounts
    LeftValveTime = R(1); RightValveTime = R(2); 
    
    % Update stimulus settings
    StimulusSettings.nTones = floor((S.GUI.SoundMaxDuration-S.GUI.ToneDuration*S.GUI.ToneOverlap)/(S.GUI.ToneDuration*(1-S.GUI.ToneOverlap)));
    StimulusSettings.ToneOverlap = S.GUI.ToneOverlap;
    StimulusSettings.ToneDuration = S.GUI.ToneDuration;
    StimulusSettings.minFreq = minFreq;
    StimulusSettings.maxFreq = maxFreq;
    StimulusSettings.UseMiddleOctave = S.GUI.UseMiddleOctave(S.GUI.UseMiddleOctave);
    StimulusSettings.Noevidence = S.GUI.NoEvidence;
    StimulusSettings.Volume = 60;

    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        
        case 1 % Left is rewarded 
            if strcmp(S.GUIMeta.FreqSide.String{S.GUI.FreqSide},'LowLeft')                
                TargetOctave = 'low';
            else
                TargetOctave = 'high';
            end
            
            LeftActionState = 'Reward'; 
            if S.GUI.Stage == 3
                RightActionState = 'Punish'; 
            else
                RightActionState = 'WaitForLeftPoke'; 
            end
            CorrectWithdrawalEvent = 'Port1Out';
            ValveCode = 1; ValveTime = LeftValveTime;
            
        case 2 % Right is rewarded
            
            if strcmp(S.GUIMeta.FreqSide.String{S.GUI.FreqSide},'LowRight')                
                TargetOctave = 'low';
            else
                TargetOctave = 'high';
            end
            
            if S.GUI.Stage == 3
                LeftActionState = 'Punish'; 
            else
                LeftActionState = 'WaitForRightPoke'; 
            end 
            RightActionState = 'Reward'; 
            CorrectWithdrawalEvent = 'Port3Out';
            ValveCode = 4; ValveTime = RightValveTime;
    end
    
    if S.GUI.PunishSound
        PsychToolboxSoundServer('Load', 3, PunishSound);
    else
        PsychToolboxSoundServer('Load', 3, 0);
    end
    
    switch S.GUI.Stage
        
        case 1 % Training stage 1: Direct sides - Poke and collect water
%             S.GUI.DifficultyLow.enable = 'off';
%             S.GUI.DifficultyHigh.enable = 'off';
%             S.GUI.nDifficulties.enable = 'off';
            S.GUI.TimeoutDuration = 0;
%             S.GUI.TimeoutDuration.enable = 'off';
            EvidenceStrength(currentTrial) = 1;            
            StimulusStateChangeConditions = {'Tup', 'Reward'};
            PostRewardState = 'exit';
        case 2 % Training stage 2: Full task, but may switch error to correct choice
            DifficultySet = [S.GUI.DifficultyLow S.GUI.DifficultyLow:(S.GUI.DifficultyHigh-S.GUI.DifficultyLow)/(S.GUI.nDifficulties-1):S.GUI.DifficultyHigh S.GUI.DifficultyHigh];
            DifficultySet = unique(DifficultySet);
            EvidenceStrength(currentTrial) = DifficultySet(randi(size(DifficultySet,2)));  
            StimulusStateChangeConditions = {'Port2Out', 'WaitForResponse'};
            PostRewardState = 'Drinking';              
        case 3 % Full task
            DifficultySet = [S.GUI.DifficultyLow S.GUI.DifficultyLow:(S.GUI.DifficultyHigh-S.GUI.DifficultyLow)/(S.GUI.nDifficulties-1):S.GUI.DifficultyHigh S.GUI.DifficultyHigh];
            DifficultySet = unique(DifficultySet);
            EvidenceStrength(currentTrial) = DifficultySet(randi(size(DifficultySet,2)));  
            StimulusStateChangeConditions = {'Port2Out', 'WaitForResponse'};
            PostRewardState = 'Drinking';
    end
    
    [Sound, Cloud, Cloud_toplot] = GenerateToneCloud(TargetOctave, EvidenceStrength(currentTrial), StimulusSettings);
    PsychToolboxSoundServer('Load', 1, Sound);

    sma = NewStateMatrix(); % Assemble state matrix

    sma = AddState(sma, 'Name', 'WaitForCenterPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'Delay'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', PrestimDuration(currentTrial),...
        'StateChangeConditions', {'Tup', 'DeliverStimulus', 'Port2Out', 'EarlyWithdrawal'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.SoundMaxDuration,...
        'StateChangeConditions', StimulusStateChangeConditions,...
        'OutputActions', {'SoftCode', 1, 'BNCState', UsingStimulation});
    sma = AddState(sma, 'Name', 'EarlyWithdrawal', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'EarlyWithdrawalPunish'},...
        'OutputActions', {'SoftCode', 255, 'BNCState', 0});
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', S.GUI.TimeForResponse,...
        'StateChangeConditions', {'Tup', 'exit', 'Port1In', LeftActionState, 'Port3In', RightActionState},...
        'OutputActions', {'SoftCode', 255, 'BNCState', 0});
    sma = AddState(sma, 'Name', 'WaitForLeftPoke', ...
        'Timer', S.GUI.TimeForReversal,...
        'StateChangeConditions', {'Tup', 'Punish', 'Port1In', 'Reward'}, ...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'WaitForRightPoke', ...
        'Timer', S.GUI.TimeForReversal,...
        'StateChangeConditions', {'Tup', 'Punish', 'Port3In', 'Reward'}, ...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', PostRewardState},...
        'OutputActions', {'ValveState', ValveCode});
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', 10,...
        'StateChangeConditions', {CorrectWithdrawalEvent, 'exit', 'Tup', 'exit'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Punish', ...
        'Timer', S.GUI.TimeoutDuration,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'SoftCode', 3});
    sma = AddState(sma, 'Name', 'EarlyWithdrawalPunish', ...
        'Timer', S.GUI.TimeoutDuration,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});

    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        %BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        BpodSystem.Data.EvidenceStrength(currentTrial) = EvidenceStrength(currentTrial); % Adds the evidence strength of the current trial to data
        BpodSystem.Data.StimulationTrials(currentTrial) = StimulationTrials(currentTrial);
        BpodSystem.Data.PrestimDuration(currentTrial) = PrestimDuration(currentTrial); % Adds the evidence strength of the current trial to data        
        BpodSystem.Data.StimulusSettings = StimulusSettings; % Save Stimulus settings
        BpodSystem.Data.Cloud{currentTrial} = Cloud; % Saves Stimulus 
        
        %Outcome
        if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
            Outcomes(currentTrial) = 1;
            AccumulatedReward = AccumulatedReward+S.GUI.RewardAmount;
            controlStep_Prestim = controlStep_Prestim+1; % update because this is a valid trial
            %controlStep_Sound = controlStep_Sound+1; % update because this is a valid trial
        elseif ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Punish(1))
            Outcomes(currentTrial) = 0;
            controlStep_Prestim = controlStep_Prestim+1; % update because this is a valid trial
            %controlStep_Sound = controlStep_Sound+1; % update because this is a valid trial
        else
            Outcomes(currentTrial) = -1;
        end
        
        BpodSystem.Data.Outcomes(currentTrial) = Outcomes(currentTrial);
        BpodSystem.Data.AccumulatedReward = AccumulatedReward;
        UpdatePerformancePlot(TrialTypes, Outcomes,SessionBirthdate);
        UpdatePsychoPlot(TrialTypes, Outcomes);
        tDeliverStimulus = diff(BpodSystem.Data.RawEvents.Trial{1, 1}.States.DeliverStimulus);
        %UpdateStimulusPlot(Cloud_toplot,tDeliverStimulus);
        PokesPlot('update');
        if S.GUI.Antibias==2 %apply antibias
            if Outcomes(currentTrial)==0
                TrialTypes(currentTrial+1)=TrialTypes(currentTrial);
            end
        end
        UpdateOutcomePlot(TrialTypes, Outcomes);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    if BpodSystem.Status.BeingUsed == 0
        PsychToolboxSoundServer('close');
        return
    end

end

function UpdateOutcomePlot(TrialTypes, Outcomes)
global BpodSystem
EvidenceStrength = BpodSystem.Data.EvidenceStrength;
nTrials = BpodSystem.Data.nTrials;
OutcomePlot(BpodSystem.GUIHandles.OutcomePlot,'update',nTrials+1,2-TrialTypes,Outcomes,EvidenceStrength);

function UpdatePerformancePlot(TrialTypes, Outcomes,SessionBirthdate)
global BpodSystem
nTrials = BpodSystem.Data.nTrials;
%PerformancePlot(BpodSystem.GUIHandles.PerformancePlot,'update',nTrials,2-TrialTypes,Outcomes,SessionBirthdate);
PerformancePlot('update', TrialTypes, Outcomes, nTrials);

function UpdatePsychoPlot(TrialTypes, Outcomes)
global BpodSystem
EvidenceStrength = BpodSystem.Data.EvidenceStrength;
nTrials = BpodSystem.Data.nTrials;
PsychoPlot(BpodSystem.GUIHandles.PsychoPlot, 'update',nTrials,2-TrialTypes,Outcomes,EvidenceStrength);

function UpdateStimulusPlot(Cloud,tDeliverStimulus)
global BpodSystem
CloudDetails.EvidenceStrength = BpodSystem.Data.EvidenceStrength(end);
StimulusPlot(BpodSystem.GUIHandles.StimulusPlot,'update',Cloud,CloudDetails,tDeliverStimulus);