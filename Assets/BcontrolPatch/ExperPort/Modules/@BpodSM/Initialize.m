% sm = Initialize(sm) 
%                This is equivalent to a reboot of the
%                StateMachine. It clears all variables, including
%                the state matrices, and initializes the
%                FSM. Initialize() does not start the
%                StateMachine running.   It is necessary to call
%                Run() to do that.
function [sm] = Initialize(sm)

     DoSimpleCmd(sm, 'INITIALIZE');
     ver = DoQueryCmd(sm, 'VERSION');
     sm.server_version = sscanf(ver, '%u');
     return;


