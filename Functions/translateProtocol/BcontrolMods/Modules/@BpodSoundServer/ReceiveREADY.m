function [] = ReceiveREADY(sm, cmd)
  [lines] = SoundTrigClient('readlines', sm.handle);
  [m,n] = size(lines);
  line = lines(1,1:n);
  if isempty(findstr('READY', line)),  error(sprintf('RTLinux FSM Server did not send READY during %s command.', cmd)); end;
end
