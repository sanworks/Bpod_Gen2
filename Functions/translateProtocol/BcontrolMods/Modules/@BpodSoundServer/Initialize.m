% sm = Initialize(sm)   
%                This is equivalent to a reboot of the
%                Sound Server. It clears all variables, including
%                the sound files, and initializes the system. 
%
%                It is not necessary to call this unless you want to clear 
%                things and start with a clean slate.
%
%                Note that multiple sm objects could potentially point to the
%                same real sound server so be careful when re-initializing 
%                the sound server, as all sounds will be reset for
%                all instances that point to the same host/port combination!
function [sm] = Initialize(sm)

     %DoSimpleCmd(sm, 'INITIALIZE');
     return;
