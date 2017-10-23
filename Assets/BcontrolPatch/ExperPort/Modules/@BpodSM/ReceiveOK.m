% [ok] = ReceiveOK(@RTLSM2::sm, const char cmd)   Checks to see if FSMServer replied with an "OK"
%
% Keeps a running counter of unaccounted-for "OK"s from the server. If this
% counter is bigger than 0, calling ReceiveOK will reduce the counter by 1
% (i.e., one OK accounted for) and the function will return a 1. If the
% counter is zero, waits for lines from the FSMServer, and for every line
% that has "OK" in it, adds 1 to the counter. If no "OK" is found in the
% lines returned by the FSMServer, returns zero and prints a warning
% message.
%
% The cmd parameter is assumed to be the last command sent to the FSMServer
% and is used merely to report it if there is an error.
%

function [ook] = ReceiveOK(sm, cmd)

% persistent n_pending_oks;
% if isempty(n_pending_oks), n_pending_oks = 0; end;
% if n_pending_oks < 0,      n_pending_oks = 0; end;
% 
% if n_pending_oks == 0,
%    % Look for OKs the Server has sent
%    lines = sm.handle.readlines;
%    for i=1:size(lines,1),
%       if ~isempty(findstr('OK', lines(i,:)))
%          n_pending_oks = n_pending_oks + 1;
%       end;
%    end;
% end;
% 
% if n_pending_oks==0,
%     errstr = sprintf('RTLinux FSM Server did not send OK after %s command.', cmd);
%     if ~isempty(lines), errstr = sprintf('%s\nInstead it sent:\n\n >> %s', errstr, lines(1,:)); end;
%     warning('BpodSM:ServerNotOK', errstr);
%     ok = 0;
% else
%     n_pending_oks = n_pending_oks-1;
%     ok = 1;
% end;
% 
% 
% if nargout>0, ook = ok; end;
ook = 1;
