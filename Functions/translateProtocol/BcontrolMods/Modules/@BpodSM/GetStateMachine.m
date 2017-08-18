% num = GetStateMachine(fsm)
%                Query the FSM server to find out which of the 6
%                state machines we are connected to.
%
function [num] = GetStateMachine(fsm)

   num = DoQueryCmd(fsm, sprintf('GET STATE MACHINE'));
   num = str2double(num);
   
