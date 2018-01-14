% Example state matrix: A global counter ends an infinite loop when 5
% Port1in events occur. Port1in events acquired in the first state are deliberately not counted.

sma = NewStateMachine();
sma = SetGlobalCounter(sma, 1, 'Port1In', 5); % Arguments: (sma, CounterNumber, TargetEvent, Threshold)
sma = AddState(sma, 'Name', 'InitialDelay', ...
    'Timer', 2,...
    'StateChangeConditions', {'Tup', 'ResetGlobalCounter1'},...
    'OutputActions', {'PWM2', 255});
sma = AddState(sma, 'Name', 'ResetGlobalCounter1', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'Port1Lit'},...
    'OutputActions', {'GlobalCounterReset', 1});
sma = AddState(sma, 'Name', 'Port1Lit', ...
    'Timer', .25,...
    'StateChangeConditions', {'Tup', 'Port3Lit', 'GlobalCounter1_End', '>exit'},...
    'OutputActions', {'PWM1', 255});
sma = AddState(sma, 'Name', 'Port3Lit', ...
    'Timer', .25,...
    'StateChangeConditions', {'Tup', 'Port1Lit', 'GlobalCounter1_End', '>exit'},...
    'OutputActions', {'PWM3', 255});