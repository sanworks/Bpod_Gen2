function [res] = DoSimpleCmd(sm, cmd)

%JPL
res=1;
%ChkConn(sm);
%res = SoundTrigClient('sendstring', sm.handle, sprintf('%s\n', cmd));

if (isempty(res))
    error(sprintf('Empty result for simple command %s, connection down?', cmd));
end;
%ReceiveOK(sm, cmd);
return;
end
