% sm = SetJumpstate(sm, ready_for_trial_jumpstate) 
%
%                This command defines the state that server as the
%                ready-for-jump state. In this state, the state machine
%                waits for a "kick" (forced-time-up) from the behavior
%                computer to go to a new state that begins a new trial.
%                The default ready-for-jump state is state 35 for
%                historical reasons. If no ready-for-jump state is
%                specified, the default (35) is used.
%
function [sm] =  SetJumpState(varargin)
  if (nargin < 1 || nargin > 3),  error ('invalid number of arguments'); end;
  sm = varargin{1};
  ready_for_trial_jumpstate = 35;
  if (nargin == 2)&& isnumeric(varargin{2}), ready_for_trial_jumpstate = varargin{2}; end;
  sm.ready_for_trial_jumpstate = ready_for_trial_jumpstate;
  ChkConn(sm);
  return;
