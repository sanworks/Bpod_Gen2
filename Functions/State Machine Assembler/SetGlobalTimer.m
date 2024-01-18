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

% SetGlobalTimer() adds a global timer to an existing state machine
% description. Global timers run in parallel with the flow of states, and
% control time measurement and automation of the state machine's onboard channels.
%
% Arguments:
% sma, a state machine description that will be modified with the new global timer
% timerIndex = a string: 'TimerIndex'. Legacy user code is supported where timerIndex is the index of the global timer to set.
% If timerIndex is 'TimerIndex', the first optional argument must be the actual timer index.
%
% Optional argument syntax: (..., 'Duration', duration, 'OnsetDelay', onsetDelay, 'Channel', channel, ...
%                                 'OnMessage', onMessage, 'OffMessage', offMessage, 'LoopMode', loopMode,...
%                                 'SendEvents', sendEvents, 'LoopInterval', loopInterval)

% For execution speed, Unused optional arguments prior to the last non-default must be specified as 0 (default).
%
% duration = Duration from timer start to timer stop in seconds (units = s).
% onsetDelay = Latency of timer onset after timer is triggered by a state (units = s)
% channel = an output channel driven by the timer onset and offset (0 = None, default).
%     Channel names depend on connected hardware, and are listed in: BpodSystem.StateMachineInfo.OutputChannelNames
%     If the channel is a digital output (BNC, Wire, FlexIO), by default the channel will be
%     set high (3.3 or 5V) when the timer starts, and low again (0V) when the timer elapses.
%     Note: State output events can still manipulate the linked channel while the timer is running.
% onMessage = (for module channels only) - the index of a byte string to send to the
%     module when the global timer starts. Byte strings are single bytes by default (i.e. 0x4 = byte 0x4),
%     but longer strings can be loaded for each byte prior to running the state machine with LoadSerialMessages()
% offMessage = (for module channels only) - the index of a byte message to
%     send to the module when the timer elapses.
% loopMode = 0 if a one-shot timer, 1 if the timer loops until stopped with the GlobalTimerCancel action (or trial end)
% sendEvents = 0 to disable wave onset and offset events (useful if looping at high frequency to control something)
% loopInterval = Configurable interval between global timer loop iterations (default = 0s).
% timerOn_Trigger = An integer whose bits indicate other global timer(s) to trigger when the timer turns on.
%
% Returns: sma, the state machine description
%
% Example usage:
% sma = SetGlobalTimer(sma, 1, 0.025); % sets timer 1 for 25ms (legacy syntax supported)
%
% sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 0.1, 'OnsetDelay', 0, 'Channel',
% 'BNC1'); % Sets timer 1 for 100ms. BNC output channel 1 will be set high when
% the timer starts, and low when it ends.
%
% sma = SetGlobalTimer(sma, 'TimerID', 3, 'Duration', 0.5, 'OnsetDelay', 1.5, 'Channel', 'Serial2', 'OnMessage', 25, 'OffMessage', 127); 
% Sets timer 3 for 0.5s. When triggered, timer 3 start following a 1500ms delay. When it starts, byte message 25 is sent to the 
% module on Serial2. When it ends (500ms later), byte message 127 is sent to the module.

function sma = SetGlobalTimer(sma, timerIndex, varargin)

global BpodSystem % Import the global BpodSystem object

% If the timer index is a char array: 'TimerID', read optional args as
% argument/value pairs. A legacy mode is supported where the first arg is
% the actual timer index.
if strcmp(timerIndex, 'TimerID') % Detect updated syntax
    timerIndex = varargin{1};
    if nargin > 3
        Duration = varargin{3};
    end
else % Assume legacy syntax
    Duration = varargin{1};
end

% Verify valid timer index
if timerIndex > BpodSystem.HW.n.GlobalTimers
    error(['Error setting global timer#' num2str(timerIndex) '. Only ' num2str(BpodSystem.HW.n.GlobalTimers)... 
          ' global timers are available.']);
end

sma.GlobalTimers.Duration(timerIndex) = Duration;

% Set onsetDelay if provided
onsetDelay = 0;
if nargin > 6
    onsetDelay = varargin{5};
end

% Set output channel
outputChannelIndex = [];
if nargin > 8
    timerOutputChannel = varargin{7};
    if ischar(timerOutputChannel)
        outputChannelIndex = find(strcmp(timerOutputChannel,BpodSystem.StateMachineInfo.OutputChannelNames));
    end
    if isempty(outputChannelIndex)
        error(['Error: ''' timerOutputChannel ''' is not a valid output channel.' char(10)... 
               'Check list of valid channels from Bpod console.']);
    end
else
    outputChannelIndex = 255;
end

% Set default params
onMessage = 0;
offMessage = 0;
loopMode = 0;
sendEvents = 1;
loopInterval = 0;
onTriggerByte = 0;
maxFlexIOVoltage = 5;

% Set onMessage to send to linked channel when timer starts
if nargin > 10
    onMessage = varargin{9};
    if BpodSystem.MachineType == 4
        if (outputChannelIndex >= BpodSystem.HW.Pos.Output_FlexIO) && (outputChannelIndex < BpodSystem.HW.Pos.Output_BNC)
            targetFlexIOChannel = outputChannelIndex - (BpodSystem.HW.Pos.Output_FlexIO-1);
            if BpodSystem.HW.FlexIO_ChannelTypes(targetFlexIOChannel) == 3
                if (onMessage > maxFlexIOVoltage) || (onMessage < 0)
                    error('Error: Flex I/O channel voltages must be in range [0, 5]');
                end
                onMessage = uint16((onMessage/maxFlexIOVoltage)*4095);
            end
        end
    end
end

% Set offMessage to send to linked channel when timer ends
if nargin > 12
    offMessage = varargin{11};
    if BpodSystem.MachineType == 4
        if (outputChannelIndex >= BpodSystem.HW.Pos.Output_FlexIO) && (outputChannelIndex < BpodSystem.HW.Pos.Output_BNC)
            targetFlexIOChannel = outputChannelIndex - (BpodSystem.HW.Pos.Output_FlexIO-1);
            if BpodSystem.HW.FlexIO_ChannelTypes(targetFlexIOChannel) == 3
                if (offMessage > maxFlexIOVoltage) || (offMessage < 0)
                    error('Error: Flex I/O channel voltages must be in range [0, 5]');
                end
                offMessage = uint16((offMessage/maxFlexIOVoltage)*4095);
            end
        end
    end
end

% Set remaining optional params
if nargin > 14
    loopMode = varargin{13};
end
if nargin > 16
    sendEvents = varargin{15};
end
if nargin > 18
    loopInterval = varargin{17};
end
if nargin > 20
    onTriggerByte = varargin{19};
end
if ischar(onTriggerByte)
    if (sum(onTriggerByte == '0') + sum(onTriggerByte == '1')) == length(onTriggerByte) % Assume binary string, convert to decimal
        onTriggerByte = bin2dec(onTriggerByte);
    else
        onTriggerByte = 2^(onTriggerByte-1); % Assume single channel
    end
end

% Set global timer
sma.GlobalTimers.OnsetDelay(timerIndex) = onsetDelay;
sma.GlobalTimers.OutputChannel(timerIndex) = outputChannelIndex;
sma.GlobalTimers.OnMessage(timerIndex) = onMessage;
sma.GlobalTimers.OffMessage(timerIndex) = offMessage;
sma.GlobalTimers.LoopMode(timerIndex) = loopMode;
sma.GlobalTimers.SendEvents(timerIndex) = sendEvents;
sma.GlobalTimers.LoopInterval(timerIndex) = loopInterval;
sma.GlobalTimers.TimerOn_Trigger(timerIndex) = onTriggerByte;
sma.GlobalTimers.IsSet(timerIndex) = 1;