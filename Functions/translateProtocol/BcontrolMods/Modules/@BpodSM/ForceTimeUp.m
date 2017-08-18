% sm = ForceTimeUp(sm) 
%                Sends a signal to the state machine that is
%                equivalent to there being a TimeUp event in the
%                state that the machine is in when the
%                ForceTimeUp() signal is received. Note that due to
%                the asynchronous nature of the link between Matlab
%                and StateMachines, the StateMachine framework
%                itself provides no guarantees as to what state the
%                machine will be in when the ForceTimeUp() signal
%                is received.
function [sm] = ForceTimeUp(sm)

     DoSimpleCmd(sm, sprintf('FORCE TIME UP'));
     sm = sm;
     return;

