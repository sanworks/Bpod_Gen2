%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2021 Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}
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
