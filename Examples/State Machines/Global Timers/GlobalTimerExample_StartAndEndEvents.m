% Example state matrix: A global timer triggers passage through two infinite loops. It is
% triggered in the first state, but begins measuring its 3-second Duration 
% after a 1.5s onset delay. During the onset delay, an infinite loop
% toggles two port LEDs (Port1, Port3) at low intensity. When the timer begins measuring, 
% it sets port 2 LED to maximum, and triggers transition to a second infinite loop with brighter port 1+3 LEDs. 
% When the timer's 3 second duration elapses, Port2LED is returned low, 
% and a GlobalTimer1_End event occurs (handled by exiting the state machine).
% Requires: behavior ports or lickometers with visible LEDs connected to Ch1, Ch2 and Ch3

sma = NewStateMachine;
sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 3, 'OnsetDelay', 1.5, 'Channel', 'PWM2'); 
sma = AddState(sma, 'Name', 'TimerTrig', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'Port1Lit_Pre'},...
    'OutputActions', {'GlobalTimerTrig', 1});
sma = AddState(sma, 'Name', 'Port1Lit_Pre', ...
    'Timer', .25,...
    'StateChangeConditions', {'Tup', 'Port3Lit_Pre', 'GlobalTimer1_Start', 'Port1Lit_Post'},...
    'OutputActions', {'PWM1', 16});
sma = AddState(sma, 'Name', 'Port3Lit_Pre', ...
    'Timer', .25,...
    'StateChangeConditions', {'Tup', 'Port1Lit_Pre', 'GlobalTimer1_Start', 'Port3Lit_Post'},...
    'OutputActions', {'PWM3', 16});
sma = AddState(sma, 'Name', 'Port1Lit_Post', ...
    'Timer', .25,...
    'StateChangeConditions', {'Tup', 'Port3Lit_Post', 'GlobalTimer1_End', '>exit'},...
    'OutputActions', {'PWM1', 255});
sma = AddState(sma, 'Name', 'Port3Lit_Post', ...
    'Timer', .25,...
    'StateChangeConditions', {'Tup', 'Port1Lit_Post', 'GlobalTimer1_End', '>exit'},...
    'OutputActions', {'PWM3', 255});

