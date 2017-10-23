% [struct time_and_events] = GetTimeEventsAndState(sm, first_event_num)    
%                Gets the time, in seconds, that has elapsed since
%                the last call to Initialize(), as well as the Events matrix
%                starting from first_event_num up until the present.
%         
%                The returned struct has the following 4 fields:
%                        time: (time in seconds)
%                        state: (state number state machine is currently in)
%                        event_ct: (event number of the latest event)
%                        events: (m by 5 matrix of events)
function [ret] = GetTimeEventsAndState(sm, first)
  ChkConn(sm);
  res = FSMClient('sendstring', sm.handle, sprintf('GET TIME, EVENTS, AND STATE %d\n', first));
  if (isempty(res)), 
    error(sprintf('Empty result for command %s, connection down?', 'GET TIME, EVENTS, AND STATE')); 
  end;
  lines = FSMClient('readlines', sm.handle);
  if (size(lines, 1) ~= 4), 
    error(sprintf('Incorrect number of lines for command %s', 'GET TIME, EVENTS, AND STATE'));
  end;
  
  line = lines(1,:); 
  [time, count, err] = sscanf(line, 'TIME %f', 1);
  if (count ~= 1), 
    error(sprintf('Parse error in result: %s: %s', line, err));
  end;

  line = lines(2,:);
  [state, count, err] = sscanf(line, 'STATE %d', 1);
  if (count ~= 1), 
    error(sprintf('Parse error in result: %s: %s', line, err));
  end;

  line = lines(3,:);
  [event_ct, count, err] = sscanf(line, 'EVENT COUNTER %d', 1);
  if (count ~= 1), 
    error(sprintf('Parse error in result: %s: %s', line, err));
  end;

  line = lines(4,:);
  [mn, count, err] = sscanf(line, 'MATRIX %d %d', 2);
  if (count ~= 2), 
    error(sprintf('Parse error in result: %s : %s', line, err));
  end;
  res = FSMClient('sendstring', sm.handle, sprintf('READY\n'));
  mat = FSMClient('readmatrix', sm.handle, mn(1), mn(2));
  ReceiveOK(sm);

  ret = struct('time', time, 'state', state, 'event_ct', event_ct+first, 'events', mat);
  
  return;
