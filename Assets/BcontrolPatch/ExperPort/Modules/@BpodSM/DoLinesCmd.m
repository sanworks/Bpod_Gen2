function [lines] = DoLinesCmd(sm, cmd)
  ChkConn(sm);
  res = FSMClient('sendstring', sm.handle, sprintf('%s\n', cmd));
  if (isempty(res)) error(sprintf('%s error, cannot send string!', cmd)); end;
  lines = FSMClient('readlines', sm.handle);
  if (isempty(lines)), error(sprintf('%s error, empty result! Is the connection down?', cmd)); end;
  nlines = sscanf(lines(1,:), 'LINES %d', 1);
  if (isempty(nlines)), error(sprintf(['%s error, cannot parse' ...
                    ' LINES\n'])); 
  end;
  while (size(lines,1) < nlines+1),
    linestmp = FSMClient('readlines', sm.handle);
    % make sure matrix sizes agree, pad with zeroes
    while (size(lines,2) > size(linestmp,2)),
      z = zeros(size(linestmp,1), 1);
      linestmp = horzcat(linestmp, z);
    end;
    while (size(linestmp,2) > size(lines,2)),
      z = zeros(size(lines,1), 1);
      lines = horzcat(lines, z);
    end;        
    lines = [ lines; linestmp ];
  end;
  
  % strip leading LINES and trailing OK
  lines = lines(2:size(lines,1)-1,:);
  

