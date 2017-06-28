% Example state matrix: TTL Pulse on BNC output 1

PulseDuration = .001;

sma = NewStateMachine;

sma = AddState(sma, 'Name', 'Pulse', ...
    'Timer', PulseDuration,...
    'StateChangeConditions', {'Tup', 'exit'},...
    'OutputActions', {'BNC1', 1});