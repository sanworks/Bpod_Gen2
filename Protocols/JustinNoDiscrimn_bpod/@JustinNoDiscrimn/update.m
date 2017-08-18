% [] = update(obj)    Method that gets called several times within each
%                     trial
%
% This method assumes that it has been given read-only access to a SPH
% called within_trial_update_actions. This should be a cell vector of
% strings, each of which will be eval'd in sequence (type "help eval" at
% the Matlab prompt if you don't know what that means).
%
% If you put everything into within_trial_update_actions, the code for this
% method should be universal for all protocols, and there should be no
% need for you to modify this file.
%

% CDB Feb 06


function [] = update(obj)

   GetSoloFunctionArgs;
   % SoloFunction('update', 'ro_args', 'within_trial_update_actions');
   
   for i=1:length(within_trial_update_actions),
      eval(within_trial_update_actions{i});
   end;



