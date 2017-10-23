function [res] = DoQueryStringtableCmd(sm, cmd)

  ChkConn(sm);
  res = FSMClient('sendstring', sm.handle, sprintf('%s\n', cmd));
  if (isempty(res)) error(sprintf('%s error, cannot send string!', cmd)); end;
  lines = FSMClient('readlines', sm.handle);
  if (isempty(lines)), error(sprintf('%s error, empty result! Is the connection down?', cmd)); end;
  [m, n] = size(lines);
  if (m >= 1 & ~isempty(findstr(lines(1, 1:n), 'ERROR'))), 
    error(sprintf(['ERROR response from server on query stringtbale command' ...
                   ' %s : %s'], cmd, lines(1,:))); 
  end;
  if (m ~= 1 | isempty(findstr(lines(1,1:n), 'URLENC STRINGTABLE'))),
    error(sprintf(['Expected single line ''URLENC STRINGTABLE m n'' from cmd:' ...
           ' %s'], cmd));
  end;

  [a, count, errmsg, nextindex] = sscanf(lines(1,:), ['URLENC' ...
                    ' STRINGTABLE %d %d']);
  if (count ~= 2), 
    error(['Error parsing URLENC STRINGTABLE response from server:' ...
    ' %s'], errmsg);
  end;
  res = FSMClient('sendString', sm.handle, sprintf('READY\n'));
  m = a(1);
  n = a(2);
  res = cell(m, n);
  nlines = 0;
  lines = [];
  while (nlines < m),
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
    nlines = size(lines,1);
  end;
  for i=1:m,
    lin = lines(i,:);
    len = size(lin,2);
    idx = 1;
    for j=1:n,      
      if (idx > len),
        error(sprintf(['Ran out of data to read in DoQueryStringtable cmd:' ...
        ' %s'], cmd));
      end;
      [tok, count, errmsg, next] = sscanf(lin(idx:len), '%s', 1);
      if (count ~= 1),
        error(sprintf(['Error parsing stringtable in DoQueryStringtable' ...
                       ' cmd: %s'], cmd));
      end;
      idx = idx+next;
      res{i,j} = UrlDecode(sm, tok);
    end;
  end;
  return;
