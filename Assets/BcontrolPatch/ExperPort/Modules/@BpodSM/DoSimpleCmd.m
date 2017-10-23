% [res] = DoSimpleCmd(sm, cmd)    Send a string to the FSM Server, not expecting a response.
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
% res   a 1 unless an error occurred.
%
%
% Example:
%
% >> DoSimpleCmd(sm, 'USE HAPPENINGS');
%

function [res] = DoSimpleCmd(sm, cmd)

     ChkConn(sm);
     res = sm.handle.sendstring(sprintf('%s\n', cmd));
     if (isempty(res)), error(sprintf('Empty result for simple command %s, connection down?', cmd)); end;
     ReceiveOK(sm, cmd);
     return;
end
