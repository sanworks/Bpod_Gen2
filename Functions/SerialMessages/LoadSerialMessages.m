%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2016 Sanworks LLC, Sound Beach, New York, USA

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
function Ack = LoadSerialMessages(SerialChannel, Messages, varargin)
% When building a state machine, The output action {"Serial1", N} can trigger byte N to be sent (default),
% or a string of bytes. This function loads byte strings for different output bytes on the UART serial channels.

% SerialChannel = Bpod UART channel
% Messages = cell array of up to 255 byte strings, each 1-3 bytes in length
% Optional argument MessageIndexes is a vector with the intended index of each message in Messages (from 1 to 255)
% Example1: LoadSerialMessages(1, {[5 10], [2 3 4]}); % Loads 0x5 0x10 as message#1, and 0x2 0x3 0x4 as message#2 on serial port 1
% Example2: LoadSerialMessages(3, ['X' 3], 23) % Loads 'X' 0x3 as message#23 on serial port 3

global BpodSystem
nMessages = length(Messages);
if ischar(Messages)
    Messages = {Messages};
    nMessages = 1;
end
if ischar(SerialChannel)
    MatchingModules = strcmp(SerialChannel, BpodSystem.Modules.Name);
    if sum(MatchingModules) == 0
        error(['Error loading serial messages: ' SerialChannel ' module not found.'])
    end
    SerialChannel = find(MatchingModules);
end
SerialMessage = zeros(1,nMessages*4); % Preallocate
if nargin > 3
    MessageIndexes = varargin{1};
else
    MessageIndexes = 1:nMessages;
end
Pos = 1;
for i = 1:nMessages
    ThisMessage = uint8(Messages{i});
    MessageLength = length(ThisMessage);
    if MessageLength > 3
        error('Error: Serial messages can only be 3 bytes in length.')
    end
    SerialMessage(Pos) = MessageIndexes(i);
    SerialMessage(Pos+1) = MessageLength;
    SerialMessage(Pos+2:Pos+MessageLength+1) = ThisMessage;
    Pos = Pos + MessageLength + 2;
end
SerialMessage = ['L' SerialChannel-1 nMessages SerialMessage(1:Pos-1)];
if BpodSystem.EmulatorMode == 0
    BpodSystem.SerialPort.write(SerialMessage, 'uint8');
    Ack = BpodSystem.SerialPort.read(1, 'uint8');
    if isempty(Ack)
        Ack = 0;
    end
else
    Ack = 1;
end