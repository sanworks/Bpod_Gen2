% Force an immediate jump to state 'state'
function [sm] = ForceState(sm, state)

     DoSimpleCmd(sm, sprintf('FORCE STATE %d ', state));
     sm = sm;
     return;
