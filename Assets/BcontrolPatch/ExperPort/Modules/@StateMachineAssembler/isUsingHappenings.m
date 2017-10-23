% [t] = is_full_trial_structure(sma)   Returns 1 if sma has been defined
%                  with the 'full_trial_structure' flag on, 0 otherwise.
%
% PARAMETERS:
% -----------
%
% sma     A @StateMachineAssembler object
%
%
% RETURNS:
% --------
%
% t       1 if sma was created with the 'full_trial_structure' flag on,
%         0 otherwise.

% Written by C. Brody Aug 2007



function [t] = isUsingHappenings(sma)

   t = sma.use_happenings == 1;
   
   