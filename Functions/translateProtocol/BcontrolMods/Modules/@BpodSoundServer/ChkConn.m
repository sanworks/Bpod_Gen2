function [] = ChkConn(sm)
  ret = SoundTrigClient('sendstring', sm.handle, sprintf('NOOP\n'));
  if (isempty(ret) | isempty((SoundTrigClient('readlines', sm.handle))))
    ret = SoundTrigClient('connect', sm.handle);
    if (isempty(ret))
      error('Unable to connect to RTLinux sound server.');
    end;
    SetCard(sm, sm.def_card);
  end;
