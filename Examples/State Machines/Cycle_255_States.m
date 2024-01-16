% Example state matrix: Runs through 255 states of 1ms each. 

sma = NewStateMachine;

for x = 1:254
eval(['sma = AddState(sma, ''Name'', ''State ' num2str(x) ''', ''Timer'', .001, ''StateChangeConditions'', {''Tup'', ''State ' num2str(x+1) '''}, ''OutputActions'', {});']);
end
sma = AddState(sma, 'Name', 'State 255', 'Timer', .001, 'StateChangeConditions', {'Tup', '>exit'}, 'OutputActions', {});