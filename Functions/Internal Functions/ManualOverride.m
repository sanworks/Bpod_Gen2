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
function ManualOverride(TargetCode, ChannelCode, varargin)
global BpodSystem
if nargin > 2
    ByteCode = varargin{1};
end

switch TargetCode(1)
    case 'I' % Input channel
        Ch = ResolveInputChannel(TargetCode(2), ChannelCode);
        BpodSystem.HardwareState.InputState(Ch) = 1-BpodSystem.HardwareState.InputState(Ch);
        OverrideMessage = ['V' Ch-1 BpodSystem.HardwareState.InputState(Ch)];
    case 'O' % Output channel
        Ch = ResolveOutputChannel(TargetCode(2), ChannelCode);
        DigitalOutputChannel = Ch-1;
        switch TargetCode(2)
            case 'S' % Assume SPI valve shift register
                if BpodSystem.HardwareState.OutputState(Ch) == 0
                    OverrideMessage = ['O' DigitalOutputChannel 2^(ByteCode-1)];
                    BpodSystem.HardwareState.OutputState(Ch) = 2^(ByteCode-1);
                else
                    OverrideMessage = ['O' DigitalOutputChannel 0];
                    BpodSystem.HardwareState.OutputState(Ch) = 0;
                end
                % If one valve is open, disable all others
                Channels = 1:8;
                ChPos = ByteCode;
                InactiveChannels = Channels(Channels ~= ChPos);
                for x = 1:7
                    if (ByteCode > 0) && BpodSystem.HardwareState.OutputState(Ch) > 0
                        set(BpodSystem.GUIHandles.PortValveButton(InactiveChannels(x)), 'Enable', 'off');
                    else
                        set(BpodSystem.GUIHandles.PortValveButton(InactiveChannels(x)), 'Enable', 'on');
                    end
                end
            case 'P'
                oldVal = BpodSystem.HardwareState.OutputState(Ch);
                if oldVal < 255
                    BpodSystem.HardwareState.OutputState(Ch) = 255;
                else
                    BpodSystem.HardwareState.OutputState(Ch) = 0;
                end
                OverrideMessage = ['O' DigitalOutputChannel BpodSystem.HardwareState.OutputState(Ch)];
            case 'B'
                BpodSystem.HardwareState.OutputState(Ch) = 1-BpodSystem.HardwareState.OutputState(Ch);
                OverrideMessage = ['O' DigitalOutputChannel BpodSystem.HardwareState.OutputState(Ch)];
            case 'W'
                BpodSystem.HardwareState.OutputState(Ch) = 1-BpodSystem.HardwareState.OutputState(Ch);
                OverrideMessage = ['O' DigitalOutputChannel BpodSystem.HardwareState.OutputState(Ch)];
            case 'U'
                switch Ch
                    case 1
                        Databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector1, 'String');
                        
                        ButtonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton1;
                    case 2
                        Databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector2, 'String');
                        ButtonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton2;
                    case 3
                        Databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector3, 'String');
                        ButtonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton3;
                    case 4
                        Databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector4, 'String');
                        ButtonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton4;
                    case 5
                        Databyte = get(BpodSystem.GUIHandles.HWSerialCodeSelector5, 'String');
                        ButtonHandle = BpodSystem.GUIHandles.HWSerialTriggerButton5;
                end
                if sum(Databyte > 57) ~= length(Databyte)
                    Databyte = str2double(Databyte);
                elseif length(Databyte) > 1
                    error('The serial message must be a single byte in the range 0-255');
                end
                if Databyte >= 0
                    Databyte = uint8(Databyte);
                elseif ischar(Databyte) && length(DataByte) == 1
                    Databyte = uint8(Databyte);
                else
                    error('The serial message must be a byte in the range 0-255');
                end
                BpodSystem.HardwareState.OutputState(Ch) = Databyte;
                OverrideMessage = ['U' Ch BpodSystem.HardwareState.OutputState(Ch)];
            case 'X' % USB
                Databyte = str2double(get(BpodSystem.GUIHandles.SoftCodeSelector, 'String'));
                ButtonHandle = BpodSystem.GUIHandles.SoftTriggerButton;
                if Databyte >= 0
                    Databyte = uint8(Databyte);
                else
                    error('The soft code must be a byte in the range 0-255');
                end
                OverrideMessage = ['S' Databyte]; % Echo soft code
        end
end

%% Send message to Bpod
if BpodSystem.EmulatorMode == 0
    BpodSystem.SerialPort.write(OverrideMessage, 'uint8');
else
    BpodSystem.VirtualManualOverrideBytes = OverrideMessage;
    BpodSystem.ManualOverrideFlag = 1;
end


%% If sending a soft byte code, flash the button to indicate success
if (TargetCode(2) == 'U') || (TargetCode(2) == 'X')
    set(ButtonHandle, 'CData', BpodSystem.GUIData.SoftTriggerActiveButton)
    drawnow;
    pause(.2);
    set(ButtonHandle, 'CData', BpodSystem.GUIData.SoftTriggerButton)
end
BpodSystem.RefreshGUI;
drawnow;

function Ch = ResolveOutputChannel(ChType, ChNum)
global BpodSystem
Channels = find(BpodSystem.HardwareState.OutputType==ChType);
Ch = Channels(ChNum);

function Ch = ResolveInputChannel(ChType, ChNum)
global BpodSystem
Channels = find(BpodSystem.HW.Inputs==ChType);
Ch = Channels(ChNum);