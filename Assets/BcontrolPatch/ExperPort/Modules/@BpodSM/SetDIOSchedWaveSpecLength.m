% sm = SetDIOSchedWaveSpecLength(sm, unsigned int n)   Define the number of items in a SchedWave specification
% 
% This command sets the number of items that go into specifying a scheduled
% wave specification. Current items are:
%
% ID IN_EVENT_COL OUT_EVENT_COL DIO_LINE SOUND_TRIG PREAMBLE SUSTAIN REFRACTION [LOOP=0] [WAVES TO TRIGGER ON ENTERING SUSTAIN=0] [WAVES TO UNTRIGGER ON LEAVING SUSTAIN=0]
%
% The allowed number of items are 8 (the default), in which case no 'loop'
% parameter is assumed to exist. If there are 9 columns, the 'loop' parameter
% is to be passed in. 10 columns means that a 32-bit mask, indicating which
% waves are to be triggered when this wave enters sustain, will be passed
% in. 11 columns means that a 32-bit mask, indicating which
% waves are to be UNtriggered when this wave leaves sustain, will be passed
% in.
%

function [sm] = SetDIOSchedWaveSpecLength(sm, n)

  if ~min_server(sm, 220090628, mfilename),
      return;
  end;
  

  [res] = FSMClient('sendstring', sm.handle, sprintf(['SET DIO SCHED WAVE NUM COLUMNS ' ...
                    '%u\n'], n)); %#ok<NASGU>
  ReceiveOK(sm, 'SET DIO SCHED WAVE NUM COLUMNS');
  
  
  return;
