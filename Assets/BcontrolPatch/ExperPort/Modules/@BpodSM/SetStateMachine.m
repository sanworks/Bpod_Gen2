% fsm = SetStateMachine(fsm, which_sm)
%                Tell the FSM server to start using which_sm.
%                which_sm is a value from 0 to 5 to indicate which
%                of the 6 state machines on the FSM server we are
%                going to use.  
%
%                Note it is important to also make sure the number
%                of the state machine corresponds to the number of
%                the soundcard used for sound triggering.  See 
%                SetOutputRouting.m
function [fsm] = SetStateMachine(fsm, which_sm)

   if (length(which_sm) ~= 1), error('Invalid argument to SetStateMachine'); end;
   
   DoSimpleCmd(fsm, sprintf('SET STATE MACHINE %d', which_sm));
   fsm.fsm_id = which_sm;
   