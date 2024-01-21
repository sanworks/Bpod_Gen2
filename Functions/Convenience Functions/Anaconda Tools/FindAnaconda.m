%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) Sanworks LLC, Rochester, New York, USA

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

% FindAnaconda() returns the path to the local installation of Anaconda.

function condaPath = FindAnaconda()

if ispc
    [~,CondaPathStr] = system('for /F "tokens=2,*" %a in (''reg query HKCU\Software\Python /f InstallPath /s /k /ve ^| findstr Default'') do @echo %b');
    condaPosInStr = strfind(CondaPathStr, 'Anaconda');
    if isempty(condaPosInStr)
        error('Error: Anaconda auto-detect failed');
    end
    nCandidates = length(condaPosInStr);
    hrPos = strfind(CondaPathStr, 10);
    pos = 1;
    found = 0;
    condaPath = [];
    for i = 1:nCandidates
      if ~found
          candidate = CondaPathStr(pos:pos+hrPos(i)-2);
          if ~isempty(strfind(CondaPathStr, 'Anaconda'))
              condaPath = candidate;
              found = 1;
          end
      end
    end
    if isempty(condaPath)
        error('Error: Anaconda auto-detect failed');
    end
else
    error('Error: Anaconda auto-detect is currently only supported on Windows');
end
