% sm = Halt(sm)  Stops the StateMachine, putting it in a halted
%                state. In this state, input events do not have 
%                any effect and state transitions are not made. 
%                Variables are not cleared, however, and so they
%                can be read by other programs (such as your Matlab
%                code).  Calling Run() will resume a halted state machine.
%
%                NB: A freshly Initialize()'d StateMachine is in the *halted*
%                state. Halting an already halted StateMachine has
%                no effect.
function [sm] = Halt(sm)
     DoSimpleCmd(sm, 'HALT');
     return;

