% [str_res] = DoQueryCmd(sm, cmd)  Send a string command to FSMServer.cpp across
%                                              TCP/IP, get single line string response.
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
% str_res   The FSM server's response.
%



function [res] = DoQueryCmd(sm, cmd)

%JPL - there may be more Bpod functionality we want to call here, but for
%now, just commenting any calls to FSMClient

global BpodSystem
ChkConn(sm);
res=1;
%res = FSMClient('sendstring', sm.handle, sprintf('%s\n', cmd));
if (isempty(res)) 
    error(sprintf('%s error, cannot send string!', cmd)); 
end;
lines='1';
%lines = FSMClient('readlines', sm.handle);
if (isempty(lines))
    error('%s error, empty result! Is the connection down?', cmd); 
end;
[m, n] = size(lines);
respos = 1;
if (m == 2)
    respos = 2; 
end;
if (~isempty(findstr(lines(respos, 1:n), 'ERROR'))),
    error('Error on query command "%s" - response was "%s"', cmd, lines');
elseif (m ~= 2 || isempty(findstr(lines(2,1:n), 'OK')) ), 
    ReceiveOK(sm, cmd); 
end; %error(sprintf('%s result status is not OK.', cmd)); end;

if (m < 1 || isempty(lines)), 
    error('Unexpected response from server on query command %s', cmd); 
end;

res=num2str(BpodSystem.FirmwareBuild);

% just to clean up the connection
%FSMClient('disconnect');

return;
end
