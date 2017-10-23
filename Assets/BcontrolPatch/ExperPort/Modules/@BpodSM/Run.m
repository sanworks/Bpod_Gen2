% sm = Run(sm)   Restarts the StateMachine: events have an effect
%                again. After an Initialize(), Run() starts the
%                machine in state 0. After a Halt(), Run() restarts
%                the machine in whatever state is was halted. Note
%                that calling Run() before the state matrices have
%                been defined produces undefined behavior and
%                should be avoided.
%
function [sm] = Run(sm)

     DoSimpleCmd(sm, 'RUN');
     sm = sm;
     return;

