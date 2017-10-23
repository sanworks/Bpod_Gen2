function [] = ReceiveREADY(sm, cmd)
  [lines] = sm.handle.readlines();
  [m,n] = size(lines);
  line = lines(1,1:n);
  if ~any(strcmp(cellstr(lines),'READY'))
  	error(sprintf('Bpod FSM Server did not send READY during %s command.', cmd)); 
  end
end
