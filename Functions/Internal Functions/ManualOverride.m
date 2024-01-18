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

% ManualOverride is used internally by the Bpod Console GUI to override valve and LED
% channels, and to create virtual events.

function ManualOverride(targetCode, channelCode, varargin)

global BpodSystem % Import the global BpodSystem object

if nargin > 2
    ByteCode = varargin{1};
end

switch targetCode(1)
    case 'I' % Input channel
        ch = resolve_input_channel(targetCode(2), channelCode);
        BpodSystem.HardwareState.InputState(ch) = 1-BpodSystem.HardwareState.InputState(ch);
        overrideMessage = ['V' ch-1 BpodSystem.HardwareState.InputState(ch)];
    case 'O' % Output channel
        ch = resolve_output_channel(targetCode(2), channelCode);
        digitalOutputChannel = ch-1;
        if digitalOutputChannel == BpodSystem.SyncConfig.Channel
            BpodErrorDlg(['You cannot override' char(10)  'the sync channel.']);
        end
        switch targetCode(2)
            case 'P'
                oldVal = BpodSystem.HardwareState.OutputState(ch);
                if oldVal < 255
                    BpodSystem.HardwareState.OutputState(ch) = 255;
                else
                    BpodSystem.HardwareState.OutputState(ch) = 0;
                end
                overrideMessage = ['O' digitalOutputChannel BpodSystem.HardwareState.OutputState(ch)];
            case 'B'
                BpodSystem.HardwareState.OutputState(ch) = 1-BpodSystem.HardwareState.OutputState(ch);
                overrideMessage = ['O' digitalOutputChannel BpodSystem.HardwareState.OutputState(ch)];
            case 'W'
                BpodSystem.HardwareState.OutputState(ch) = 1-BpodSystem.HardwareState.OutputState(ch);
                overrideMessage = ['O' digitalOutputChannel BpodSystem.HardwareState.OutputState(ch)];
            case 'V'
                BpodSystem.HardwareState.OutputState(ch) = 1-BpodSystem.HardwareState.OutputState(ch);
                overrideMessage = ['O' digitalOutputChannel BpodSystem.HardwareState.OutputState(ch)];
                if BpodSystem.MachineType < 3
                    % If one valve is open, disable all others
                    channels = 1:8;
                    chPos = ch-BpodSystem.HW.Pos.Output_Valve+1;
                    inactiveChannels = channels(channels ~= chPos);
                    for x = 1:7
                        if BpodSystem.HardwareState.OutputState(ch) > 0
                            set(BpodSystem.GUIHandles.PortValveButton(inactiveChannels(x)), 'Enable', 'off');
                        else
                            set(BpodSystem.GUIHandles.PortValveButton(inactiveChannels(x)), 'Enable', 'on');
                        end
                    end
                end
            case 'U'
                switch ch
                    case 1
                        databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector1, 'String');
                        
                        buttonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton1;
                    case 2
                        databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector2, 'String');
                        buttonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton2;
                    case 3
                        databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector3, 'String');
                        buttonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton3;
                    case 4
                        databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector4, 'String');
                        buttonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton4;
                    case 5
                        databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector5, 'String');
                        buttonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton5;
                end
                if sum(databyte > 57) ~= length(databyte)
                    databyte = str2double(databyte);
                elseif length(databyte) > 1
                    error('The serial message must be a single byte in the range 0-255');
                end
                if databyte >= 0
                    databyte = uint8(databyte);
                elseif ischar(databyte) && length(databyte) == 1
                    databyte = uint8(databyte);
                else
                    error('The serial message must be a byte in the range 0-255');
                end
                BpodSystem.HardwareState.OutputState(ch) = databyte;
                overrideMessage = ['U' ch BpodSystem.HardwareState.OutputState(ch)];
            case 'X' % USB
                databyte = str2double(get(BpodSystem.GUIHandles.SoftCodeSelector, 'String'));
                buttonHandle = BpodSystem.GUIHandles.SoftTriggerButton;
                if databyte >= 0
                    databyte = uint8(databyte);
                else
                    error('The soft code must be a byte in the range 0-255');
                end
                overrideMessage = ['S' databyte]; % Echo soft code
        end
end

% Send message to Bpod
if BpodSystem.EmulatorMode == 0
    BpodSystem.SerialPort.write(overrideMessage, 'uint8');
else
    BpodSystem.VirtualManualOverrideBytes = overrideMessage;
    BpodSystem.ManualOverrideFlag = 1;
end


% If sending a soft byte code, flash the button to indicate success
if (targetCode(2) == 'U') || (targetCode(2) == 'X')
    set(buttonHandle, 'CData', BpodSystem.GUIData.SoftTriggerActiveButton)
    drawnow;
    pause(.2);
    set(buttonHandle, 'CData', BpodSystem.GUIData.SoftTriggerButton)
end
BpodSystem.RefreshGUI;
drawnow;

function ch = resolve_output_channel(chType, chNum)
global BpodSystem
channels = find(BpodSystem.HardwareState.OutputType==chType);
ch = channels(chNum);

function ch = resolve_input_channel(chType, chNum)
global BpodSystem
channels = find(BpodSystem.HW.Inputs==chType);
ch = channels(chNum);