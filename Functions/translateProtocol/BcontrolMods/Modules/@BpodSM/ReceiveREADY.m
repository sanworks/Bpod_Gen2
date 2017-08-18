function [] = ReceiveREADY(sm, cmd)
lines='1 READY';
%[lines] = FSMClient('readlines', sm.handle);
[m,n] = size(lines);
line = lines(1,1:n);
if isempty(findstr('READY', line)),
    error(sprintf('Bpod Server did not send READY during %s command.', cmd));
end;
end
