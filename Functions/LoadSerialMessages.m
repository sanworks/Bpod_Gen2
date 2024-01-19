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

% LoadSerialMessages() programs the state machine's serial message library.
% The serial message library stores multi-byte messages that can be sent to
% the associated module when referenced by index in the OutputActions section
% of a state description.
%
% Input Arguments:
% module = Bpod module channel number OR module name (e.g. 'AnalogIn1')
% messages = cell array of up to 255 byte strings. Byte strings can be up
%            to 3 bytes long (State Machine r0.5-r1) or 5 bytes long (State Machine r2, 2.5, 2+ with firmware v23 or newer)
% messageIndexes (optional) is a vector with the intended index of each message in Messages (from 1 to 255)
% 
% Output Arguments:
% ack, the acknowledgement flag. 1 if the messages were received by the state machine, 0 if not.
%
% Usage Examples:
% Example1: LoadSerialMessages(1, {[5 10], [2 3 4]}); % Loads 0x5 0x10 as message#1, and 0x2 0x3 0x4 as message#2 on serial port 1
% Example2: LoadSerialMessages('AnalogIn1', ['X' 3], 23) % Loads ['X' 0x3] as message#23 on the channel attached to AnalogIn1
%
% *Note* For a marginal speed penalty, you can entirely avoid usage of
%        LoadSerialMessages() by adding multi-byte arrays directly to the state
%        definition, e.g. in OutputActions: {'HiFi1', ['P' 0]} to send the play
%        command to the HiFi module. If you do this, you must do it across your
%        protocol as the positions of the messages in the library will be managed
%        by the software.

function ack = LoadSerialMessages(module, messages, varargin)

global BpodSystem % Import the global BpodSystem object

MAX_MESSAGE_LENGTH = BpodSystem.HW.n.MaxBytesPerSerialMsg;

nMessages = length(messages);

% Contain messages in cell array if char provided
if ischar(messages)
    messages = {messages};
    nMessages = 1;
end

% Verify existence of target module
if ischar(module)
    matchingModules = strcmp(module, BpodSystem.Modules.Name);
    if sum(matchingModules) == 0
        error(['Error loading serial messages: ' module ' module not found.'])
    end
    module = find(matchingModules);
end

serialMessage = zeros(1,nMessages*4); % Preallocate

% Import optional argument: messageIndexes or create default
if nargin >= 3
    messageIndexes = varargin{1};
else
    messageIndexes = 1:nMessages;
end

% Format messages
Pos = 1;
for i = 1:nMessages
    thisMessage = uint8(messages{i});
    messageLength = length(thisMessage);
    if messageLength > MAX_MESSAGE_LENGTH
        error(['Error: Serial messages can only be ' num2str(MAX_MESSAGE_LENGTH) ' bytes in length.'])
    end
    serialMessage(Pos) = messageIndexes(i);
    serialMessage(Pos+1) = messageLength;
    serialMessage(Pos+2:Pos+messageLength+1) = thisMessage;
    Pos = Pos + messageLength + 2;
end

% Prepare byte string, send to state machine and read confirmation
serialMessage = ['L' module-1 nMessages serialMessage(1:Pos-1)];
if BpodSystem.EmulatorMode == 0
    BpodSystem.SerialPort.write(serialMessage, 'uint8');
    ack = BpodSystem.SerialPort.read(1, 'uint8');
    if isempty(ack)
        ack = 0;
    end
else
    ack = 1;
end