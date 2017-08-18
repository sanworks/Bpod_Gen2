% Example state matrix: Runs through 8 states of 1ms each.
% Sends a pulse train on BNC trigger channel 1, where alternating states
% are high and low.
% Useful for bench-testing SYNC line.
pulseWidth = 0.001; %(s)
sma = NewStateMachine;
i = 1;
for x = 1:20
    eval(['sma = AddState(sma, ''Name'', ''State ' num2str(x) ''', ''Timer'', ' num2str(pulseWidth) ', ''StateChangeConditions'', {''Tup'', ''State ' num2str(x+1) '''}, ''OutputActions'', {''BNCState'',' num2str(i) '});']);
    i = 1-i;
end
sma = AddState(sma, 'Name', ['State ' num2str(x+1)], 'Timer', pulseWidth, 'StateChangeConditions', {'Tup', 'exit'}, 'OutputActions', {});