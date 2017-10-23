% [smm ok] = SendHappeningSpec(sm, spec, ok_required=0)   Sends the available happening specs to FSMServer
%
% THIS FUNCTION IS USUALLY USED INTERNALLY, AND IS CALLED BY
% SetStateMatrix.m. THE FUNCTION IS HERE FOR DEBUGGING PURPOSES BUT USERS
% SHOULD NOT NORMALLY NEED TO CALL IT.
% 
% PARAMETERS:
% -----------
%
% sm              The obligatory @RTLSM2 object 
%
% spec            a vector structure, where the elements i have the fields:
%
%       spec(i).name    A string-- this is what this happening will be known
%                       as to the user. E.g., "mywave_High" or "Cin".
%
%       spec(i).detectorFunctionName   Another string. This one defines the
%                       internal happening detector function to use. For 
%                       example, "line_high". To get a description of available
%                       happening detector function, do 
%                          >> DoLinesCmd(sm, 'GET HAPPENING DETECTOR FUNCTIONS');
%
%       spec(i).inputNumber  An integer. This will be a parameter passed to the
%                       detector function when checking for this happening. For
%                       example, Cin typically uses "line_in" on input line 1,
%                       so Cin would use a 1 here.
%
%       spec(i).happId  An integer, that uniquely identifies this happening. This
%                       is a number that will be used, together with a timestamp,
%                       to report back to the client which happenings occurred.
%
%       An example of a spec structure that could be used is:
%
%       spec = struct( ...
%         'name',                  {'Cin',     'Cout',     'Lin',     'Lout'}, ...
%         'detectorFunctionName',  {'line_in', 'line_out', 'line_in', 'line_out'}, ...
%         'inputNumber',           {1,          1,          2,         2    }, ...
%         'happId',                {1,          2,          3,         4    });
%
%       Note how the happId is unique for each entry, and so is the name, but the
%       detectorFunctionName and the inputNumber are not unique across entries.
%       It is the *combination* of these last two that is unique and that maps
%       1-to-1 onto happIds and names.
%          You don't have to enter all possible combinations into your spec--
%       just the ones you want to use.
%
% ok_required An optional scalar, by default 0.  If this is zero, no "OK"
%             response from the RTLinux Server is expected. This is the
%             mode in which it should be used when SendHappeningSpec.m is
%             called from within a SET STATE MATRIX command (see
%             SetStateMatrix.m). If this is a 1, then an "OK" response from
%             the server is expected and waited for.
%
% RETURNS:
% --------
%
% 1 if all went well, 0 if an OK response was requested but did not arrive.
%

% Carlos Brody June 2009


function [sm, ok] = SendHappeningSpec(sm, spec, ok_required)

if nargin<3, ok_required = 0; end;

if ~min_server(sm, 220090628, mfilename),
    ok = 0;
    return;
end;

reqfields = {'name', 'detectorFunctionName', 'inputNumber', 'happId'};

if ~isstruct(spec) || ~isempty(setdiff(reqfields, fields(spec))),
    error('RTLSM2:BadSyntax', 'spec must be a structure with fields %s', reqfields);
end;

res = FSMClient('sendstring', sm.handle, sprintf('SET HAPPENINGS SPEC\n'));
if res ~= 1, error('RTLSM2:BadConnection', 'Couldn''t communicate with the FSM Server'); end;

res = FSMClient('sendstring', sm.handle, sprintf('%d\n', numel(spec)));
if res ~= 1, error('RTLSM2:BadConnection', 'Couldn''t communicate with the FSM Server'); end;

for i=1:numel(spec),
    res = FSMClient('sendstring', sm.handle, sprintf('%s %s %d %d\n', ...
        spec(i).name, spec(i).detectorFunctionName, spec(i).inputNumber, spec(i).happId));
    if res ~= 1, error('RTLSM2:BadConnection', 'Couldn''t communicate with the FSM Server'); end;
end;

if ok_required,
   ok = ReceiveOK(sm, 'SET HAPPENINGS SPEC');
else
   ok = 1;
end;

sm.happSpec = spec;

