% Example state matrix: A global timer ends an infinite loop
% Requires: behavior ports or lickometers with visible LEDs connected to Ch1 and Ch2

sma = NewStateMachine();
sma = SetGlobalTimer(sma, 1, 3); %This legacy syntax is supported. Arguments: (sma, GlobalTimerNumber, Duration(s))
sma = AddState(sma, 'Name', 'TimerTrig', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'Port1Lit'},...
    'OutputActions', {'GlobalTimerTrig', 1});
sma = AddState(sma, 'Name', 'Port1Lit', ...
    'Timer', .25,...
    'StateChangeConditions', {'Tup', 'Port2Lit', 'GlobalTimer1_End', '>exit'},...
    'OutputActions', {'PWM1', 255});
sma = AddState(sma, 'Name', 'Port2Lit', ...
    'Timer', .25,...
    'StateChangeConditions', {'Tup', 'Port1Lit', 'GlobalTimer1_End', '>exit'},...
    'OutputActions', {'PWM2', 255});

