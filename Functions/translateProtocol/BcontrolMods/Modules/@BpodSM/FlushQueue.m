% sm = FlushQueue(sm)   
%
%                In the RTLSM2, this does nothing.
%
%                Some state machines (e.g., RM1s, RTLinux boxes)
%                will be self-running; others need a periodic ping
%                to operate on events in their incoming events
%                queue. This function is used for the latter type
%                of StateMachines. In self-running state machines,
%                it is o.k. to define this function to do nothing.
function [sm] = FlushQueue(sm)
% NOOP for now?
  sm = sm;
  return;
