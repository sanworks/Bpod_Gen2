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

function [sma, smIndex] = addImplicitSerialMessage(sma, channel, message)

% Input arguments:
% sma: A Bpod State Machine description created with NewStateMachine()
% channel: The channel index. Must be a serial channel (Bpod Module)
% message: A single or multi-byte message to store to the state machine's message library

global BpodSystem
if channel <= BpodSystem.HW.n.Outputs
    if BpodSystem.HW.Outputs(channel) == 'U'
        % Verify message length
        messageLength = length(message);
        if messageLength > BpodSystem.HW.n.MaxBytesPerSerialMsg
            error(['State ' stateName ' contains a ' num2str(messageLength) '-byte serial message.' ...
                newline 'The maximum message length supported by your state machine firmware is ' ...
                num2str(BpodSystem.HW.n.MaxBytesPerSerialMsg) ' bytes.'])
        end
        messageIndex = 0;
        for i = 1:sma.nSerialMessages(channel)
            thisMessage = sma.SerialMessages{i};
            if length(thisMessage) == messageLength
                if sum(thisMessage == message) == messageLength
                    messageIndex = i;
                end
            end
        end
        if messageIndex > 0
            smIndex = messageIndex;
        else
            sma.nSerialMessages(channel) = sma.nSerialMessages(channel) + 1;
            thisMessageIndex = sma.nSerialMessages(channel);
            sma.SerialMessages{channel,thisMessageIndex} = uint8(message);
            smIndex = thisMessageIndex;
        end
        sma.SerialMessageMode = 1;
    else
        error('The target channel for addImplicitSerialMessage() must be a serial (Bpod module) channel.')
    end
end

