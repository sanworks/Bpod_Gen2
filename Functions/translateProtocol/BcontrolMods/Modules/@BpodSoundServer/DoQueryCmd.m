function [res] = DoQueryCmd(sm, cmd)

  ChkConn(sm);
  res = SoundTrigClient('sendstring', sm.handle, sprintf('%s\n', cmd));
  if (isempty(res)) error(sprintf('%s error, cannot send string!', cmd)); end;
  lines = SoundTrigClient('readlines', sm.handle);
  if (isempty(lines)), error(sprintf('%s error, empty result! Is the connection down?', cmd)); end;
  [m, n] = size(lines);
  respos = 1;
  if (m == 2), respos = 2; end;
  if (~isempty(findstr(lines(respos, 1:n), 'ERROR'))), error(sprintf('Unexpected response from server on query command %s', cmd)); 
  elseif (m ~= 2 | isempty(findstr(lines(2,1:n), 'OK')) ), ReceiveOK(sm, cmd); end; %error(sprintf('%s result status is not OK.', cmd)); end;
  if (m < 1 | isempty(lines)), error(sprintf('Unexpected response from server on query command %s', cmd)); end;
  res = lines(1,1:n);

  % just to clean up the connection
  %fsmclient('disconnect');

  return;
end
