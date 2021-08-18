function CondaPath = FindAnaconda()
if ispc
    [~,CondaPathStr] = system('for /F "tokens=2,*" %a in (''reg query HKCU\Software\Python /f InstallPath /s /k /ve ^| findstr Default'') do @echo %b');
    CondaPosInStr = strfind(CondaPathStr, 'Anaconda');
    if isempty(CondaPosInStr)
        error('Error: Anaconda auto-detect failed');
    end
    nCandidates = length(CondaPosInStr);
    HRpos = strfind(CondaPathStr, 10);
    Pos = 1;
    Found = 0;
    CondaPath = [];
    for i = 1:nCandidates
      if ~Found
          Candidate = CondaPathStr(Pos:Pos+HRpos(i)-2);
          if ~isempty(strfind(CondaPathStr, 'Anaconda'))
              CondaPath = Candidate;
              Found = 1;
          end
      end
    end
    if isempty(CondaPath)
        error('Error: Anaconda auto-detect failed');
    end
else
    error('Error: Anaconda auto-detect is currently only supported on Windows');
end
