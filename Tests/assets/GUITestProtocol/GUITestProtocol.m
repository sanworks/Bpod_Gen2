function TestProtocol(varargin)
global BpodSystem

p = inputParser();
p.addParameter('verbose', true)
p.addParameter('gui', true)
p.addParameter('maxTrials', 3)
p.parse(varargin);

S = BpodSystem.ProtocolSettings;

if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.CurrentBlock = 1; % Training level % 1 = Direct Delivery at both ports 2 = Poke for delivery
    S.GUI.RewardAmount = 5; %ul
    S.GUI.PortOutRegDelay = 0.5; % How long the mouse must remain out before poking back in
end

if p.Results.gui
    BpodParameterGUI('init', S);
end

maxTrials = p.Results.maxTrials;

for currentTrial = 1:maxTrials
    if p.Results.gui
        S = BpodParameterGUI('sync', S);
    end

    % Test getting valve values
    valveAction = {'ValveState', };

    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'EnterState',...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'OpenValve'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'ValveCheck',...
        'Timer', valveDur,...
        'StateChangeConditions', {'Tup', 'ExitState'},...
        'OutputActions', valveAction);
    sma = AddState(sma, 'Name', 'ExitState',...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {});
    

    SendStateMachine(sma)

    RawEvents = RunStateMachine;
    if isempty(fieldnames(RawEvents))
        break
    end

    BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
    if p.Results.gui
        BpodSystem.Data = BpodNotebook('sync', BpodSystem.Data); % Sync with Bpod notebook plugin
    end
    BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct
    BpodSystem.Data.TrialTypes(currentTrial) = trialTypes(currentTrial); % Adds the trial type of the current trial to data
    outcomePlot.update(trialTypes, BpodSystem.Data); % Update the outcome plot
    SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file

    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.

    % Exit the session if the user has pressed the end button
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

end