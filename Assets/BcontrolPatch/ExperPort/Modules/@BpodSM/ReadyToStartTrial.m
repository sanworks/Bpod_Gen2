% sm = ReadyToStartTrial(sm) 
%                Signals to the StateMachine that it is ok
%                to start a new trial. After this routine is called,
%                the next time that the StateMachine reaches state 35,
%                it will immediately jump to state 0, and a new trial starts.
%
%
function [sm] = ReadyToStartTrial(sm)

     DoSimpleCmd(sm, 'READY TO START TRIAL');
     sm = sm;
     return;

