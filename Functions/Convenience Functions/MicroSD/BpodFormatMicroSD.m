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

% BpodFormatMicroSD erases and formats the microSD card of a Bpod module.
% - The module must first be loaded with Bpod_FormatMicroSD firmware via LoadBpodFirmware()
%
% - The correct firmware variant is:
%   FormatMicroSD_T41: HiFi Module, Analog Input v2, Analog Output v2
%   FormatMicroSD_T36: Analog Input v1, Analog Output v1
%   FormatMicroSD_T35: Rotary Encoder v1
%
% - After using BpodFormatMicroSD, restore the module's firmware with LoadBpodFirmware()
%
% Arguments:
% port (char array), the name of the USB serial port of the target module.

function BpodFormatMicroSD(port)

% Setup and init
A = ArCOMObject_Bpod(port); % Open ArCOM USB serial interface
A.flush;
A.write('F', 'uint8'); % Write 'F' command to format the card

% Verify microSD card initialization
sd_initOK = A.read(1, 'uint8');
if isempty(sd_initOK)
    sd_initOK = 0;
end
if ~sd_initOK
    failErrorMsg(A, 'MicroSD initialization');
end

% Verify microSD card erase operation
sd_eraseOK = A.read(1, 'uint8');
if isempty(sd_eraseOK)
    sd_eraseOK = 0;
end
if ~sd_eraseOK
    failErrorMsg(A, 'MicroSD erase operation');
end

% Verify format operation
pause(1);
formatMsg = A.read(A.bytesAvailable, 'char');
if isempty(strfind(formatMsg, 'Done')) %#ok, contains() fails on r2016a and earlier
    failErrorMsg(A, 'MicroSD format operation');
else
    disp(formatMsg(1:end-2));
    disp(' ');
    disp('Run LoadBpodFirmware() to restore the module''s firmware')
end

function failErrorMsg(Port, OpName)
    pause(1);
    Port.flush;
    error([OpName ' failed.'])