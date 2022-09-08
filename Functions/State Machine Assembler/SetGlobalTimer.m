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
function sma = SetGlobalTimer(sma, TimerID, varargin)
global BpodSystem
% TimerNumber = the ID of the global timer to set. Valid timer IDs are usually 1-5 (depending on firmware, there may be more).

% Optional arguments: (..., Duration, myduration, OnsetDelay, mydelay, Channel, mychannel, ...
%                      OnMessage, my_onmessage, OffMessage, my_offmessage, LoopMode, my_loopmode,...
%                      SendEvents, y_n, LoopInterval, myInterval)
% For execution speed, Unused optional arguments prior to the last non-default must be specified as 0 (default).
%
% Duration = Duration from timer start to timer stop in seconds (default = 0s).
% OnsetDelay = Latency of timer onset after timer is triggered by a state
% Channel = an output channel driven by the timer onset and offset (0 = None, default).
%     Channel names depend on connected hardware, and are listed in: BpodSystem.StateMachineInfo.OutputChannelNames
%     If the channel is a digital output (BNC, Wire), the channel will be
%     set high (3.3 or 5V) when the timer starts, and low again (0V) when the timer elapses.
%     Note: State output events can still manipulate the linked channel while the timer is running.
% OnMessage = (for serial channels only) - the index of a byte string to send to the
%     module when the global timer starts. Byte strings are single bytes by default (i.e. 0x4 = byte 0x4),
%     but longer strings can be loaded for each byte prior to running the state machine with LoadSerialMessages()
% OffMessage = (for serial channels only) - the index of a byte message to
%     send to the module when the timer elapses.
% LoopMode = 0 if a one-shot timer, 1 if the timer loops until stopped with the GlobalTimerCancel action (or trial end)
% SendEvents = 0 to disable wave onset and offset events (useful if looping at high frequency to control something)
% LoopInterval = Configurable interval between global timer loop iterations (default = 0s).
% TimerOn_Trigger = An integer whose bits indicate other global timers to trigger when the timer turns on.
%
% Example usage:
% sma = SetGlobalTimer(sma, 1, 0.025); % sets timer 1 for 25ms (legacy syntax supported)
%
% sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', 0.1, 'OnsetDelay', 0, 'Channel',
% 'BNC1'); % Sets timer 1 for 100ms. BNC output channel 1 will be set high when
% the timer starts, and low when it ends.
%
% sma = SetGlobalTimer(sma, 'TimerID', 3, 'Duration', 0.5, 'OnsetDelay', 1.5, 'Channel', 'Serial2', 'OnMessage', 25, ...
%                      'OffMessage', 127); % Sets timer 3 for 0.5s. When triggered, timer 3 starts
% following a 1500ms delay. When it starts, byte message 25 is sent to the
% module on Serial2. When it ends (500ms later), byte message 127 is sent
% to the module.
if strcmp(TimerID, 'TimerID') % Detect updated syntax
    TimerID = varargin{1};
    if nargin > 3
        Duration = varargin{3};
    end
else % Assume legacy syntax
    Duration = varargin{1};
end

if TimerID > BpodSystem.HW.n.GlobalTimers
    error(['Error setting global timer#' num2str(TimerID) '. Only ' num2str(BpodSystem.HW.n.GlobalTimers) ' global timers are available.']);
end
sma.GlobalTimers.Duration(TimerID) = Duration;
OnsetDelay = 0;
if nargin > 6
    OnsetDelay = varargin{5};
end
OutputChannelIndex = [];
if nargin > 8
    TimerOutputChannel = varargin{7};
    if ischar(TimerOutputChannel)
        OutputChannelIndex = find(strcmp(TimerOutputChannel,BpodSystem.StateMachineInfo.OutputChannelNames));
    end
    if isempty(OutputChannelIndex)
        error(['Error: ''' TimerOutputChannel ''' is not a valid output channel.' char(10) 'Check list of valid channels from Bpod console.']);
    end
else
    OutputChannelIndex = 255;
end
OnMessage = 0;
OffMessage = 0;
LoopMode = 0;
SendEvents = 1;
LoopInterval = 0;
OnTriggerByte = 0;
MaxFlexIOVoltage = 5;
if nargin > 10
    OnMessage = varargin{9};
    if BpodSystem.MachineType == 4
        if (OutputChannelIndex >= BpodSystem.HW.Pos.Output_FlexIO) && (OutputChannelIndex < BpodSystem.HW.Pos.Output_BNC)
            TargetFlexIOChannel = OutputChannelIndex - (BpodSystem.HW.Pos.Output_FlexIO-1);
            if BpodSystem.HW.FlexIO_ChannelTypes(TargetFlexIOChannel) == 3
                if (OnMessage > MaxFlexIOVoltage) || (OnMessage < 0)
                    error('Error: Flex I/O channel voltages must be in range [0, 5]');
                end
                OnMessage = uint16((OnMessage/MaxFlexIOVoltage)*4095);
            end
        end
    end
end
if nargin > 12
    OffMessage = varargin{11};
    if BpodSystem.MachineType == 4
        if (OutputChannelIndex >= BpodSystem.HW.Pos.Output_FlexIO) && (OutputChannelIndex < BpodSystem.HW.Pos.Output_BNC)
            TargetFlexIOChannel = OutputChannelIndex - (BpodSystem.HW.Pos.Output_FlexIO-1);
            if BpodSystem.HW.FlexIO_ChannelTypes(TargetFlexIOChannel) == 3
                if (OffMessage > MaxFlexIOVoltage) || (OffMessage < 0)
                    error('Error: Flex I/O channel voltages must be in range [0, 5]');
                end
                OffMessage = uint16((OffMessage/MaxFlexIOVoltage)*4095);
            end
        end
    end
end
if nargin > 14
    LoopMode = varargin{13};
end
if nargin > 16
    SendEvents = varargin{15};
end
if nargin > 18
    LoopInterval = varargin{17};
end
if nargin > 20
    OnTriggerByte = varargin{19};
end

if ischar(OnTriggerByte)
    if (sum(OnTriggerByte == '0') + sum(OnTriggerByte == '1')) == length(OnTriggerByte) % Assume binary string, convert to decimal
        OnTriggerByte = bin2dec(OnTriggerByte);
    else
        OnTriggerByte = 2^(OnTriggerByte-1); % Assume single channel
    end
end

sma.GlobalTimers.OnsetDelay(TimerID) = OnsetDelay;
sma.GlobalTimers.OutputChannel(TimerID) = OutputChannelIndex;
sma.GlobalTimers.OnMessage(TimerID) = OnMessage;
sma.GlobalTimers.OffMessage(TimerID) = OffMessage;
sma.GlobalTimers.LoopMode(TimerID) = LoopMode;
sma.GlobalTimers.SendEvents(TimerID) = SendEvents;
sma.GlobalTimers.LoopInterval(TimerID) = LoopInterval;
sma.GlobalTimers.TimerOn_Trigger(TimerID) = OnTriggerByte;
sma.GlobalTimers.IsSet(TimerID) = 1;