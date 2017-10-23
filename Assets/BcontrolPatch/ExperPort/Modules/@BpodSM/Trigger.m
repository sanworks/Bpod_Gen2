% [] = Trigger(sm, int d) 
%                Bypass the control over sound triggers, and set
%                off the indicated sound trigger. 
%
function [] = Trigger(sm, d)

     DoSimpleCmd(sm, sprintf('TRIGSOUND %d', d));
     return;
