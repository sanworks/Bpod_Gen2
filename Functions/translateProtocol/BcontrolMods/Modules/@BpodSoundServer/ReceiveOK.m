function [] = ReceiveOK(sm, cmd)
  lines = SoundTrigClient('readlines', sm.handle);
  [m,n] = size(lines);
  line = lines(1,1:n);
  if isempty(findstr('OK', line)),  error(sprintf('RTLinux FSM Server did not send OK after %s command.', cmd)); end;
end
