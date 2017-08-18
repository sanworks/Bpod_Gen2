%parseargs   [] = parseargs(arguments, pairs)
%
% Variable argument parsing-- This function is meant to be used in the
% context of other functions which have variable arguments. Typically, the
% function using variable argument parsing would be written with the
% following header:
%
%    function myfunction(args, ..., varargin)
%
% and would define the variable "pairs" (in a
% format described below), and would then include the line
%
%       parseargs(varargin, pairs);
%
% 'pairs' specifies how the variable arguments should
% be parsed; its format is decribed below. It is best
% understood by looking at the example at the bottom of these help 
% comments.
%
% PARSEARGS DOES NOT RETURN ANY VALUES; INSTEAD, IT USES ASSIGNIN
% COMMANDS TO CHANGE OR SET VALUES OF VARIABLES IN THE CALLING
% FUNCTION'S SPACE.  
%
%
%
% PARAMETERS:
% -----------
%
% -arguments     The varargin list, I.e. a row cell array.
%
% -pairs         A cell array of all those arguments that are
%                specified by argument-value pairs. First column
%                of this cell array must indicate the variable
%                names; the second column must indicate
%                correponding default values. 
%
%
%
% Example:
% --------
%
% In "pairs", the first column defines both the variable name and the 
% marker looked for in varargin, and the second column defines that
% variable's default value:
%
%   pairs = {'thingy'  20 ; ...
%            'blob'    'that'};
%
%
% 
% Now for the function call from the user function:
%
%   parseargs({'blob', 'fuff!'}, pairs);
%
% This will set, in the caller space, thingy=20, and blob='fuff!'. Since
% default values are in the second column of "pairs", and in the call to
% parseargs 'thingy' was not specified, 'thingy' takes on its
% default value of 20. 
%
% Note that the arguments to parseargs may be in any order-- the
% only ordering restriction is that whatever immediately follows
% pair names (e.g. 'blob') will be interpreted as the value to be
% assigned to them (e.g. 'blob' takes on the value 'fuff!');
%
%

% Carlos Brody

function [] = parseargs(arguments, pairs)
   
for i=1:size(pairs,1),
   assignin('caller', pairs{i,1}, pairs{i,2});
end;
if isempty(pairs),   pairs   = {'', []}; end;

arg = 1;
while arg <= length(arguments),
   
   switch arguments{arg},
      case pairs(:,1),
         if arg+1 <= length(arguments)
            assignin('caller', arguments{arg}, arguments{arg+1});
            arg = arg+1;
         else
            me = MException('parseargs:badSyntax', 'name-value pair had name "%s" but no value', arguments{arg});
            throwAsCaller(me);
         end;
         
         
      otherwise
         me = MException('parseargs:unknownID', 'Don''t know how to handle "%s"', arguments{arg});
         throwAsCaller(me);
         
   end;

   arg = arg+1; 
end;
   
return;

   