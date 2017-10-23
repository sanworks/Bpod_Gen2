function [sm] = Initialize(sm)

   mydata = get(sm.myfig, 'UserData');
   mydata.sound1 = [];
   mydata.sound2 = [];
   mydata.sound4 = [];
   set(sm.myfig, 'UserData', mydata);

   % If on a MAC, kill all previous soundservers and start a fresh one
   if strcmp(computer, 'MAC') | strcmp(computer, 'MACI'),
      st = dbstack('-completenames');
      pathstr = fileparts(st(1).file);
      [stat, res] = unix(['cd "' pathstr ...
                          '"; ./kill_by_name.pl /usr/local/bin/playsound']);
      [stat, res] = unix(['cd "' pathstr '"; ./kill_by_name.pl soundserver']);
      [stat, res] = unix(['cd "' pathstr '"; ./soundserver.sh &']);
   end;
