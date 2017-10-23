function [currentState] = GetState(sm)
    ChkConn(sm);
    currentState = str2num(DoQueryCmd(sm, 'GET CURRENT STATE'));
    return;
end
