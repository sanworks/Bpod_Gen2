% [sm] = ClearScheduledWaves(sm)
%                 Clears all the scheduled waves specified by calls to
%                 SetScheduledWaves.  Like SetScheduledWaves, this takes
%                 effect after the next call to SetStateMatrix.
function [sm] = ClearScheduledWaves(sm)
    sm.sched_waves = zeros(0, size(sm.sched_waves,2));
    sm.sched_waves_ao = cell(0, size(sm.sched_waves_ao,2));
    sm = sm;
    return;
    
