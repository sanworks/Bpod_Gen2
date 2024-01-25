% Example state matrix: Runs through 20 states of 1ms each.
% Sends a pulse train on BNC output channel 2, where alternating states
% are high and low.

pulseWidth = 0.001; %(s)
sma = NewStateMachine;
i = 1;
for x = 1:20
    eval(['sma = AddState(sma, ''Name'', ''State ' num2str(x) ''', ''Timer'', '...
        num2str(pulseWidth) ', ''StateChangeConditions'', {''Tup'', ''State ' num2str(x+1)...
        '''}, ''OutputActions'', {''BNCState'',' num2str(i*2) '});']);
    i = 1-i;
end
sma = AddState(sma, 'Name', ['State ' num2str(x+1)], 'Timer', pulseWidth,...
    'StateChangeConditions', {'Tup', '>exit'}, 'OutputActions', {});