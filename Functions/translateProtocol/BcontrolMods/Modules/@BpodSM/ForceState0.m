% Force an immediate jump to state 0
function [sm] = ForceState0(sm)

     sm = ForceState(sm, 0);
     return;
