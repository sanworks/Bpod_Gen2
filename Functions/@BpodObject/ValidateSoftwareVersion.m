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

% BpodObject.ValidateSoftwareVersion() checks Github for a newer stable
% release than the current software. If new software is available, it
% prints an update notice in the MATLAB command window.

function ValidateSoftwareVersion(obj)

% Get the installed version
ver = BpodSoftwareVersion_Semantic;
latestVersion = [];

% Get the remote version
[reply, ~] =... 
urlread('https://raw.githubusercontent.com/sanworks/Bpod_Gen2/master/Functions/Internal%20Functions/BpodSoftwareVersion_Semantic.m');
verPos = find(reply == '=');
if ~isempty(verPos)
    latestVersion = strtrim(reply(verPos(end)+2:end-2));
end

% Compare and display update notice if necessary
if ~isempty(latestVersion)
    verDiff = CompareBpodVersions(ver, latestVersion);
    if verDiff < 0  
        disp( '***********************************************************')
        disp(['UPDATE NOTICE: Bpod Console v' latestVersion ' is available to download!'])
        disp(['                 View release notes '...
              '<a href="matlab:web(''https://github.com/sanworks/Bpod_Gen2/blob/master/Release%20Notes.txt'',''-browser'')">here</a>'])
        disp(['To update run UpdateBpodSoftware() OR see instructions'... 
             '<a href="matlab:web(''https://sanworks.github.io/Bpod_Wiki/install-and-update/software-update/'',''-browser'')">here</a>'])
        disp( '***********************************************************')
    elseif verDiff > 0
        disp( '***********************************************************')
        disp(['NOTE: You are running a dev version of Bpod Console: ' sprintf('%3.2f', ver) char(10)...
              'The latest stable release is: ' latestVersion]) %#ok
        disp( '***********************************************************')
    end
end