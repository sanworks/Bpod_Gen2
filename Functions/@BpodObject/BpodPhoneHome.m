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

% BpodObject.BpodPhoneHome() launches a GUI to share information about Bpod setups.
% BpodPhoneHome is disabled by default. If the Bpod user opts in, it will send
% anonymous data about your Bpod installation, MATLAB version and OS to a
% secure server owned and operated by Sanworks LLC each time the Bpod program
% or a protocol is started, and only if an Internet connection is detected.
%
% This data will help Sanworks developers understand how Bpod is typically configured,
% and how to prioritize features and fixes in the future. For instance, if
% we notice that users on Ubuntu OS + MATLAB pre r2023a restart
% Bpod unusually frequently, we may allocate extra debuggung effort to ensure
% the stability of that configuration.
%
% If another user of your installation has opted in, and you want to disable
% this feature, run BpodSystem.PhoneHomeOpt_In_Out() from the command line
% OR manually set 'PhoneHome' to 0 in BpodSettings.mat (usually in your
% /BpodLocal/ directory). If you want to participate, set 'PhoneHome' to 1.
%
% The argument 'op' can be: 0 (startup event) 1 (protocol run event) or 2
% (Bpod crash/error event)
%
% Please be courteous, and do not misuse this function to spam our server.
% Our goal is to make Bpod as stable as possible for Neuroscience researchers everywhere.
% Thank you, -Josh Sanders Nov 2017.

function BpodPhoneHome(obj, op)

optedIn = 1;
if ischar(op)
    if strcmp(op, 'Opt_Out')
        optedIn = 0;
    end
end

if optedIn == 1
    machine = num2str(obj.MachineType);
    fv = num2str(obj.FirmwareVersion);
    sv = BpodSoftwareVersion_Semantic;
    if ispc
        WinVer = [];
        [~,reply]=system('ver');
        if ~isempty(strfind(reply, ' 5.1')) || ~isempty(strfind(reply, ' 5.2')) %#ok contains() requires r2016b but Bpod supports back to r2013a
            WinVer = 'XP';
        elseif ~isempty(strfind(reply, ' 6.0')) %#ok
            WinVer = 'VA'; % Vista
        elseif ~isempty(strfind(reply, ' 6.1')) %#ok
            WinVer = '7';
        elseif ~isempty(strfind(reply, ' 6.2')) %#ok
            WinVer = '8';
        elseif ~isempty(strfind(reply, ' 10.')) %#ok
            WinVer = '10';
        end
        OS = ['W' WinVer];
    elseif ismac
        OS = 'OSX';
    else
        OS = 'LNX';
    end
    v = ver('matlab');
    matlabV = v.Release;
    matlabV = matlabV(2:end-1);
    emuMode = num2str(obj.EmulatorMode);
    if (op == 0) || (op == 1) || (op == 2)
        OP = num2str(op);
    else
        error('Error: Invalid op')
    end
end
id = obj.SystemSettings.PhoneHomeRigID;
key = 'WESh0ULD@LLSw1TcH2PYtHOn';
if verLessThan('matlab', '8.1')
    protocol = 'http://'; % MATLAB versions older than r2013a cannot use SSL without extensive configuration
    useSSL = 0;
else
    protocol = 'http://';
    useSSL = 0;
    %     Protocol = 'https://'; % Beginning on 8 Feb 2018, even newer MATLAB versions fail at the SSL handshake.
    %     useSSL = 1;
end
if optedIn == 1
    ReadUrl([protocol 'sanworks.io/et/phonehome.php?machine=' machine '&firmware=' fv '&software=' sv '&os=' OS '&matver=' matlabV '&emu=' emuMode '&op=' OP '&id=' id '&key=' key], useSSL);
else
    ReadUrl([protocol 'sanworks.io/et/opt_out.php?id=' id '&key=' key], useSSL); % Inform Sanworks LLC of the opt-out so we can accurately measure the fraction of users that chose to participate
end
end

function str = ReadUrl(url, useSSL)
str = [];
try
    if useSSL
        is = java.net.URL([], url, sun.net.www.protocol.https.Handler).openConnection().getInputStream();
    else
        is = java.net.URL([], url, sun.net.www.protocol.http.Handler).openConnection().getInputStream();
    end
    br = java.io.BufferedReader(java.io.InputStreamReader(is));
    str = char(br.readLine());
catch
    % Fail silently; PhoneHome must not stop the science!
end
end