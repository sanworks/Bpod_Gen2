% ret = DoSimpleSetCommand(sm, str cmd, setval) Sends a command that also requires sending a 
%                 single scalar or string value to the FSMServer.
% 
% PARAMETERS:
% -----------
%
% sm   an RTLSM object
%
% cmd  a string, sent to the FSM server.
%
% setval  A string or a scalar to be sent on the same line to the server.
%
% RETURNS:
% --------
%
% ret   a 1 unless an error occurred.
%
%
% Example:
%
% DoSimpleSetCommand(sm, 'SET DIO SCHED WAVE NUM COLUMNS', 11);
%


function [out] = DoSimpleSetCommand(sm, cmd, setval)

   if numel(setval)~=1 || (~isnumeric(setval) || ischar(setval)),
     warning('RTLSM2:BadCommand', 'DoSimpleSetCommand can only send scalar or string values, ignoring the request');
     return;
   end;

   if isnumeric(setval)
     [res] = FSMClient('sendstring', sm.handle, sprintf('%s %g\n', cmd, setval)); %#ok<NASGU>
     if ~ReceiveOK(sm, cmd), out=0; return; end;
   elseif ischar(setval)
     [res] = FSMClient('sendstring', sm.handle, sprintf('%s %s\n', cmd, setval)); %#ok<NASGU>
     if ~ReceiveOK(sm, cmd), out=0; return; end;
   end;     
   
   out=1;
   return;
