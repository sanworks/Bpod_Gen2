% [result_matrix] = DoQueryMatrixCmd(sm, cmd)  Send a command that expects a matrix in return
%
% This function takes care of sending the command, getting an ok back,
% getting a message that indicates what size matrix to expect, sending the
% ready signal, and then getting the matrix. Don't use this command if you
% expect a scalar or string response.
%
% PARAMETERS:
% -----------
%
% sm   an RTLSM object
%
% cmd  a string, sent to the FSM server.
%
% RETURNS:
% --------
%
% result_matrix   A matrix that is the FSM server's response.
%


function [result_matrix] = DoQueryMatrixCmd(sm, cmd)

  ChkConn(sm);
  res = FSMClient('sendstring', sm.handle, sprintf('%s\n', cmd));
  if (isempty(res)), error(sprintf('%s error, connection down?', cmd)); end;
  lines = FSMClient('readlines', sm.handle);
  if (isempty(lines)), error(sprintf('%s error, empty result! Connection down?', cmd)); end;
  [m, n] = size(lines);
  if (m ~= 1), error(sprintf('%s got unexpected response.', cmd)); end;
  if (~isempty(strfind(lines(1,1:n), 'ERROR'))), error(sprintf('%s got ERROR response', cmd)); end;
  line = lines(1,1:n);
  [matM, matN] = strread(line, 'MATRIX %d %d');
  if (isempty(matM) || isempty(matN)), error(sprintf('%s got bogus response %s when querying matrix size.', cmd, line)); end;
  FSMClient('sendstring', sm.handle, sprintf('%s\n', 'READY'));
  mat = FSMClient('readmatrix', sm.handle, matM, matN);
  % grab the 'OK' at the end
   ReceiveOK(sm); 
   %fsmclient('disconnect');
   result_matrix = mat;
   % just to clean up the connection
   return;
end
