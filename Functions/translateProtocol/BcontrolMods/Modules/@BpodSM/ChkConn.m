function [a] = ChkConn(sm)
global BpodSystem
if isempty(BpodSystem)
    a=0; 
else
    a=1;
end

