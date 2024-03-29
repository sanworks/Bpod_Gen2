% Example state matrix: Switches states when a TTL pulse arrives on BNC trigger channel 1
% Requires: behavior ports or lickometers with visible LEDs connected to Ch1 and Ch2


sma = NewStateMachine();

sma = AddState(sma, 'Name', 'Port1LightOn', ...
    'Timer', 1,...
    'StateChangeConditions', {'BNC1High', 'Port2LightOn'},...
    'OutputActions', {'PWM1', 255});
sma = AddState(sma, 'Name', 'Port2LightOn', ...
    'Timer', 1,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'PWM2', 255});