% Example state machine description using the '>back' command to return to the previous state. 
% Entry to port 1 lights up port 1 for 1 second. 
% Entry to port 2 lights up port 2 for 1 second.
% Both states go to "waiting". Entry to port 1 or 2 exits. Entry to port 3
% sends the SM back to the previous state (flash port 1 or 2, depending on which it was).
% Requires: behavior ports or lickometers with visible LEDs connected to Ch1, Ch2 and Ch3

sma = NewStateMachine;

sma = AddState(sma, 'Name', 'WaitForChoice', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port1In', 'FlashPort1','Port2In', 'FlashPort2'},...
    'OutputActions', {});
sma = AddState(sma, 'Name', 'FlashPort1', ...
    'Timer', 0.5,...
    'StateChangeConditions', {'Tup', 'WaitForExit'},...
    'OutputActions', {'LED', 1});
sma = AddState(sma, 'Name', 'FlashPort2', ...
    'Timer', 0.5,...
    'StateChangeConditions', {'Tup', 'WaitForExit'},...
    'OutputActions', {'LED', 2});
sma = AddState(sma, 'Name', 'WaitForExit', ...
    'Timer', 0,...
    'StateChangeConditions', {'Port1In', '>exit', 'Port2In', '>exit', 'Port3In', '>back'},...
    'OutputActions', {});