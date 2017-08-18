function linearTrack

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S

%% Initialize plots

% Initialize parameter GUI plugin

S=KatieBCS1_9_bpod('init',S);

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);

% Notebook
BpodNotebook('init');


%% Define stimuli and send to sound server
MaxTrials=1000;
tic
%% Main trial loop
for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    
    S = KatieBCS1_9_bpod('update',S);

    sma = NewStateMatrix(); % Assemble state matrix

    sma = AddState(sma, 'Name', 'waitForMove', ...
        'Timer', 0,...
        'StateChangeConditions', {'Encoder', 'Moving'},...
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'Moving', ...
        'Timer', PrestimDuration(currentTrial),...
        'StateChangeConditions', {'StimTTL', 'DeliverStimulus', 'LickPort', 'Reward'},...
        'OutputActions', {});
    
    sma = AddState(sma, 'Name', 'applyBrake', ...
        'Timer', S.GUI.brakeTime,...
        'OutputActions', {'Tup', 'Moving', 'BNCState', UsingStimulation});
    
    
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', Moving},...
        'OutputActions', {'ValveState', ValveCode});


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
    if BpodSystem.BeingUsed == 0
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