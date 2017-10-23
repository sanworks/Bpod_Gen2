% [sm] = SetHappeningList(sm, happlist)   Set the list of happenings for
%                                   each state. Will not take effect until
%                                   next SetStateMatrix.
%
% THIS FUNCTION IS DEPRECATED AND SHOULD BE REMOVED. SETTING THE HAPPENING
% LIST IS NOW PART OF THE CALL TO SET STATE MATRIX
% 
% happlist must be an n-by-1 cell n = total number of states in the current
% state machine diagram. Each row thus corresponds to a state. Each element
% must in turn be a cell, which must have an even number of entries. All
% the odd-numbered entries must be strings, and must be one of the strings
% defined as a happening name in the happening spec for the current state
% machine diagram (see SetHappeningSpec.m). For example, these strings might
% typically be something like 'Clo', or 'mwave_hi'. The even-numbered
% elements must be the state number to jump to if immediately previous
% happening (e.g., 'Clo') occurs when in this state.
%
% An example of a simple state machine follows. This toggles back and forth
% between two states depending on whether the center poke beam is
% interrupted ("C is high") or not ("C is low"). But in either of those
% states, it exits to a third state if the Left poke beam is interrupted
% ("L is high") and stays there until the Right poke beam is interrupted:
%
% happList = { ...
%   {'Chi'  1  'Lhi'  2} ; ...  % state 0: jump to 1 if Chi, jump to 2 if Lhi
%   {'Clo'  0  'Lhi'  2} ; ...  % state 1
%   {'Rhi'  0} ; ...            % state 2
% };
%
%

% Carlos Brody June 2009


function [sm] = SetHappeningList(sm, happList)

if ~min_server(sm, 220090628, mfilename),
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


sm.happList = happList;


