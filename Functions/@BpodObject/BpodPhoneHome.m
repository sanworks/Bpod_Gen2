%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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
function BpodPhoneHome(obj)
% BpodPhoneHome is disabled by default. If the Bpod user opts in, it will send
% anonymous data about your Bpod installation, MATLAB version and OS to a
% secure server owned and operated by Sanworks LLC each time the Bpod program
% is started, and only if an Internet connection is detected.
%
% This data will help Sanworks developers understand how Bpod is typically configured,
% and how to prioritize features and fixes in the future.
% If another user of your installation has opted in, and you want to disable
% this feature, set 'PhoneHome' to 0 in BpodSettings.mat (usually in your
% /BpodLocal/ directory). If you want to participate, set 'PhoneHome' to 1.
%
% Please be courteous, and do not misuse this function to spam our server.
% Our goal is to make Bpod as stable as possible for Neuroscience researchers everywhere.
% Thank you, -Josh Sanders Nov 2017.

Machine = num2str(obj.MachineType);
FV = num2str(obj.FirmwareVersion);
SV = num2str(BpodSoftwareVersion);
if ispc
    WinVer = [];
    [a,reply]=system('ver');
    if ~isempty(strfind(reply, ' 5.1')) || ~isempty(strfind(reply, ' 5.2'))
        WinVer = 'XP';
    elseif ~isempty(strfind(reply, ' 6.0'))
        WinVer = 'VA'; % Vista
    elseif ~isempty(strfind(reply, ' 6.1'))
        WinVer = '7';
    elseif ~isempty(strfind(reply, ' 6.2'))
        WinVer = '8';
    elseif ~isempty(strfind(reply, ' 10.'))
        WinVer = '10';
    end
    OS = ['W' WinVer];
elseif ismac
    OS = 'OSX';
else
    OS = 'LNX';
end
v = ver('matlab');
MatlabV = v.Release;
MatlabV = MatlabV(2:end-1);
emuMode = num2str(obj.EmulatorMode);
Key = ['WESh0ULD@LLSw1TcH2PYtHOn'];
if verLessThan('matlab', '8.1')
    Protocol = 'http://'; % MATLAB versions older than r2013a cannot use SSL without extensive configuration
    useSSL = 0;
else
    Protocol = 'https://';
    useSSL = 1;
end
Reply = ReadUrl([Protocol 'sanworks.io/et/phonehome.php?machine=' Machine '&firmware=' FV '&software=' SV '&os=' OS '&matver=' MatlabV '&emu=' emuMode '&key=' Key], useSSL);
end

function str = ReadUrl(url, useSSL)
    if useSSL
        is = java.net.URL([], url, sun.net.www.protocol.http.Handler).openConnection().getInputStream(); 
    else
        is = java.net.URL([], url, sun.net.www.protocol.http.Handler).openConnection().getInputStream(); 
    end
    br = java.io.BufferedReader(java.io.InputStreamReader(is));
    str = char(br.readLine());
end