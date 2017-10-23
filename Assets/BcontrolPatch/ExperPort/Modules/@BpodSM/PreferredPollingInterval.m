% [intvl_ms] = PreferredPollingInterval(sm)    
%
%                In the RTLSM2 this does nothing.
%
%                For machines that require FlushQueue() calls, this
%                function returns the preferred interval between
%                calls. Note that there is no guarantee that this
%                preferred interval will be respected. intvl_ms is
%                in milliseconds. 
function [interval_ms] =  PreferredPollingInterval(sm)
     interval_ms = 10;
     return;

