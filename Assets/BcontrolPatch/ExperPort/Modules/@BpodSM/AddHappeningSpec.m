% [sm] = AddHappeningSpec(sm, spec)   Add to the available happening specs.
%                        Will not take effect until next SetStateMatrix
%
% Adds new specs to the existing specs by concatenating to the current list.
%
% spec must be vector structure, where the elements i have the fields:
%
% spec(i).name    A string-- this is what this happening will be known
%                 as to the user. E.g., "mywave_High" or "Cin".
%
% spec(i).detectorFunctionName   Another string. This one defines the
%                 internal happening detector function to use. For 
%                 example, "line_high". To get a description of available
%                 happening detector function, do 
%                    >> DoLinesCmd(sm, 'GET HAPPENING DETECTOR FUNCTIONS');
%
% spec(i).inputNumber  An integer. This will be a parameter passed to the
%                 detector function when checking for this happening. For
%                 example, Cin typically uses "line_in" on input line 1,
%                 so Cin would use a 1 here.
%
% spec(i).happId  An integer, that uniquely identifies this happening. This
%                 is a number that will be used, together with a timestamp,
%                 to report back to the client which happenings occurred.
%
% An example of a spec structure that could be used is:
%
% spec = struct( ...
%   'name',                  {'Cin',     'Cout',     'Lin',     'Lout'}, ...
%   'detectorFunctionName',  {'line_in', 'line_out', 'line_in', 'line_out'}, ...
%   'inputNumber',           {1,          1,          2,         2    }, ...
%   'happId',                {1,          2,          3,         4    });
%
% Note how the happId is unique for each entry, and so is the name, but the
% detectorFunctionName and the inputNumber are not unique across entries.
% It is the *combination* of these last two that is unique and that maps
% 1-to-1 onto happIds and names.
%    You don't have to enter all possible combinations into your spec--
% just the ones you want to use.
%

% Carlos Brody August 2009


function [sm] = AddHappeningSpec(sm, spec)

if ~min_server(sm, 220090628, mfilename),
    return;
end;

reqfields = {'name', 'detectorFunctionName', 'inputNumber', 'happId'};

if ~isstruct(spec) || ~isempty(setdiff(reqfields, fields(spec))),
    error('RTLSM2:BadSyntax', 'spec must be a structure with fields %s', reqfields);
end;

sm.happSpec = [sm.happSpec ; spec];

