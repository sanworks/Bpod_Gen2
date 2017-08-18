% function [sm] = SetStateNames(sm, M_by_2_cell_array)
%
% Sets the mapping of state numbers to state names
% Pass in an M by 2 cell array where:
% the number of rows corresponds to the mapped states
% and each row consists of a state name -> state number(s) array.
%
% The first column is a cell containing a string which is the name
% of the state.
%
% The second column contains an array (1xn vector) of scalars
% indicating the state numbers that belong to this state name. 
%
% So for instance if you wanted states 1, 35, 3, and 7 to belong to
% and share the label 'extra_iti_states' and state 40 to have the
% state name 'wait_for_cpoke' you would call this method as such:
%
% sm = SetStateNames(sm, { 'wait_for_cpoke' [ 40 ]; ...
%                          'extra_iti_states' [ 1 35 3 7 ]; } );
%
% Then, in the state matrix window you will see, rather than the
% raw state number, the text name of the state.
%
% State41 42 41 41 41 41 41 41 100.0 0 0
%
% becomes:
%
% State41/wait_for_cpoke       42 41/wait_for_cpoke 41/wait_for_cpoke 41/wait_for_cpoke 41/wait_for_cpoke 41/wait_for_cpoke 41/wait_for_cpoke 100.0 0 0
function [sm] = SetStateNames(sm, nvp)
    warning('This function is not supported for RTLSM2 objects!');
    return;
    