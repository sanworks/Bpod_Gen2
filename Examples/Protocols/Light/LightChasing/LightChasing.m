function LightChasing
global BpodSystem
MaxTrials = 10000;
%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.StimulusDuration = 0.1; % Stimulus duration in seconds
    S.GUI.RewardAmount = 5; %ul
    S.GUI.FlashLeftLight = 'FlashLights(1)';
    S.GUIMeta.FlashLeftLight.Style = 'pushbutton';
    S.GUI.FlashRightLight = 'FlashLights(3)';
    S.GUIMeta.FlashRightLight.Style = 'pushbutton';
end

%% Define trials
TrialTypes = round(rand(1,MaxTrials)) + 1; % Randomly interleaved trial types 1 and 2
BpodSystem.Data.TrialTypes = TrialTypes; % The trial type of each trial completed will be added here.
%% Initialize plots
BpodNotebook('init'); % Bpod Notebook (to record text notes about the session or individual trials)
BpodParameterGUI('init', S); % Initialize parameter GUI plugin
%% Main trial loop
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]);   % Update reward amounts
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1
            LeftAction = 'Reward'; RightAction = 'Punish'; StimulusOutputActions = {'LED', 1}; RewardOutputActions = {'Valve', 1}; ValveTime = R(1); 
        case 2
            RightAction = 'Reward'; LeftAction = 'Punish'; StimulusOutputActions = {'LED', 3}; RewardOutputActions = {'Valve', 3}; ValveTime = R(2);
    end
    sma = NewStateMatrix(); % Assemble state matrix
    sma = AddState(sma, 'Name', 'WaitForPoke', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port2In', 'DeliverStimulus'},...
        'OutputActions', {}); 
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.StimulusDuration,...
        'StateChangeConditions', {'Tup', 'WaitForResponse', 'Port2Out', 'WaitForResponse'},...
        'OutputActions', StimulusOutputActions);
    sma = AddState(sma, 'Name', 'WaitForResponse', ...
        'Timer', 0,...
        'StateChangeConditions', {'Port1In', LeftAction, 'Port3In', RightAction},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Reward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', RewardOutputActions); 
    sma = AddState(sma, 'Name', 'Punish', ...
        'Timer', 5,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {}); 
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

