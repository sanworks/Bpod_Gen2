function [sm, state_machine] = Connect(sm, state_machine)
   
   if ~isa(stat_machine, 'softsm')
      error(['Don''t know how to connect to a ' class(state_machine) ...
             ' type state machine']);
   end;
   
   state_machine = Set_Trigout_Callback(state_machine, @playsound, sm)
   
   