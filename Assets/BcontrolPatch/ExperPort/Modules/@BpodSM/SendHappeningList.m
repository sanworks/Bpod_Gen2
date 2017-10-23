% [sm, ok] = SendHappeningList(sm, happlist, ok_required=0)   Set the list of happenings for each state
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
% happlist         must be an n-by-1 cell n = total number of states in the current
%           state machine diagram. Each row thus corresponds to a state.
%           Each element must in turn be a cell, which must have an even
%           number of entries. All the odd-numbered entries must be
%           strings, and must be one of the strings defined as a happening
%           name in the happening spec for the current state machine
%           diagram (see SetHappeningSpec.m). For example, these strings
%           might typically be something like 'Clo', or 'mwave_hi'. The
%           even-numbered elements must be the state number to jump to if
%           immediately previous happening (e.g., 'Clo') occurs when in
%           this state. 
%
%           An example of a simple state machine follows. This toggles back
%           and forth between two states depending on whether the center
%           poke beam is interrupted ("C is high") or not ("C is low"). But
%           in either of thos states, it exits to a third state if the Left
%           poke beam is interrupted ("L is high") and stays there until
%           the Right poke beam is interrupted:
%
%        happList = { ...
%           {'Chi'  1  'Lhi'  2} ; ...  % state 0: jump to 1 if Chi, jump to 2 if Lhi
%           {'Clo'  0  'Lhi'  2} ; ...  % state 1
%           {'Rhi'  0} ; ...            % state 2
%         };
%
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


function [sm, ok] = SendHappeningList(sm, happList, ok_required)

if nargin<3, ok_required = 0; end;

if ~min_server(sm, 220090628, mfilename),
    ok=0;
    return;
end;

if ~iscell(happList) || size(happList,2) ~= 1,
    error('RTLSM2:BadSyntax', 'happList must be a cell with only one column');
end;

totalHappenings = 0;
for i=1:numel(happList)
    if size(happList{i},1)>1 || rem(numel(happList{i}), 2) ~= 0,
        error('RTLSM2:BadSyntax', ['each row of happList must be a cell with a single row, ' ...
            'and an even number of entries']);
    end;
    totalHappenings = totalHappenings + numel(happList{i})/2;
    for j=1:2:numel(happList{i})
        if ~ischar(happList{i}{j}) || ~isnumeric(happList{i}{j+1}),
            error('RTLSM2:BadSyntax', ['odd-numbered entries in rows of happList must be ' ...
                'strings, even-numbered entries must be numbers']);
        end;
    end;
end;


res = FSMClient('sendstring', sm.handle, sprintf('SET HAPPENINGS LIST\n'));
if res ~= 1, error('RTLSM2:BadConnection', 'Couldn''t communicate with the FSM Server'); end;

res = FSMClient('sendstring', sm.handle, sprintf('%d\n', totalHappenings));
if res ~= 1, error('RTLSM2:BadConnection', 'Couldn''t communicate with the FSM Server'); end;

for i=1:numel(happList),
    myHapps = happList{i};
    res = FSMClient('sendstring', sm.handle, sprintf('%d\n', numel(myHapps)/2));
    if res ~= 1, error('RTLSM2:BadConnection', 'Couldn''t communicate with the FSM Server'); end;
    
    for j=1:2:numel(myHapps),
        res = FSMClient('sendstring', sm.handle, sprintf('%s %d\n', myHapps{j}, myHapps{j+1}));
        if res ~= 1, error('RTLSM2:BadConnection', 'Couldn''t communicate with the FSM Server'); end;
    end;
end;

if ok_required,
   ok = ReceiveOK(sm, 'SET HAPPENINGS LIST');
else
   ok = 1;
end;

sm.happList = happList;


