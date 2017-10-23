function [] = ChkConn(sm)
  if (sm.in_chkconn),  return;  end;
  ret = sm.handle.sendstring(sprintf('NOOP\n'));
  if (isempty(ret) | isempty((sm.handle.readlines())))
    if (isempty(ret))
      error('Unable to connect to Bpod/Bcontrol Interface.');
    end;
%     sm.in_chkconn = 1;
%     ChkVersion(sm);
%     SetStateMachine(sm, sm.fsm_id); % tell state machine server
%                                     % about which fsm id we have
%                                     % since we just reconnected and
%                                     % it defaults to fsm id 0
%     sm.in_chkconn = 0;
  end;

