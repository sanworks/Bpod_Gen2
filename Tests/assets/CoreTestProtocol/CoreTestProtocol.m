function CoreTestProtocol()
% Protocol to verify that BpodSystem can run a protocol.
% Doesn't include any GUI components, so it can run headless.

global BpodSystem

BpodSystem.SoftCodeHandlerFunction = 'TestSoftCodeHandler';
valvetime = GetValveTimes(5, 1);

sma = NewStateMachine();
sma = AddState(sma, 'Name', 'Start', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'End'},...
    'OutputActions', {'ValveState', 1, 'BNCState', 1}); % Open valve and set BNC
sma = AddState(sma, 'Name', 'SoftCode', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'End'},...
    'OutputActions', {'SoftCode', 1});
sma = AddState(sma, 'Name', 'End', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'exit'},...
    'OutputActions', {});

SendStateMachine(sma);
RawEvents = RunStateMachine;
BpodSystem.Data = AddTrialEvents(BpodSystem.Data, RawEvents);
BpodSystem.Data.TrialOutcomes = 1; % For verification that it ran
SaveBpodSessionData

end