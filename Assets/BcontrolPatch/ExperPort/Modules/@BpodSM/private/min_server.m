% [ok] = min_server(sm, min_version, [cmd])     Checks to see whether the
%                   server version (obtained on Initialize(sm)) is at least
%                   as large as min_version. If so, returns a 1. If not,
%                   returns a 0. If the third argument, cmd, is present, it
%                   must be a string; in that case, min_server prints a
%                   report out to the console when returning a 0.
%
%
% PARAMETERS:
% -----------
%
% sm             An RTLSM object
%
% min_version    A number
%
% cmd            A string
%

% Carlos Brody June 2009


function [ok] = min_server(sm, min_version, cmd)

if nargin < 3, cmd = ''; end;

if isempty(sm.server_version),
    error('Have you run @%s/Initialize.m? I don''t know what the server version is!', class(sm));
end;

if ( sm.server_version < min_version),
   if ~isempty(cmd),
      fprintf(1, '\n***** WARNING! %s requires a minimum\n   server version %d,\nyou are using\n   server version %d\n\n', ...
         cmd, min_version, sm.server_version);
   end;
   ok = 0;
else
   ok = 1;
end;

