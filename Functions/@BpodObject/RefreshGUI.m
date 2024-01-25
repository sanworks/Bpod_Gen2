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

% BpodObject.RefreshGUI() is called during behavior measurement to update
% the Bpod Console GUI's state and event display fields, and to color the 
% override buttons indicating channel status. 
% The GUI elements are updated to match the current status in BpodObject.Status
% Calling functions are RunStateMachine() and BpodTrialManager()

function obj = RefreshGUI(obj)
    % Update most recent state and event names
    if ~isempty(obj.StateMatrix)
        set(obj.GUIHandles.PreviousStateDisplay, 'String', obj.Status.LastStateName);
        set(obj.GUIHandles.CurrentStateDisplay, 'String', obj.Status.CurrentStateName);
        if obj.Status.LastEvent > 0
            if obj.Status.LastEvent <= length(obj.StateMachineInfo.EventNames)
                set(obj.GUIHandles.LastEventDisplay, 'String', obj.StateMachineInfo.EventNames{obj.Status.LastEvent});
            end
        end
    end

    % Update output channel override button colors
    startPos = obj.HW.n.SerialChannels;
    changedOutputChannels = find(obj.HardwareState.OutputState ~= obj.LastHardwareState.OutputState);
    changedOutputChannels = changedOutputChannels(changedOutputChannels>startPos);
    for i = changedOutputChannels
        thisChannelType = obj.HardwareState.OutputType(i);
        thisChannelState = obj.HardwareState.OutputState(i);
        lastChannelState = obj.LastHardwareState.OutputState(i);
        switch thisChannelType
            case 'S' % Assume this SPI channel is a power shift register to control valves
                for j = 1:8
                    valveState = bitget(thisChannelState,j);
                    lastValveState = bitget(lastChannelState, j);
                    if valveState ~= lastValveState
                        if obj.GUIData.CurrentPanel == 1
                            if valveState == 1
                                set(obj.GUIHandles.PortValveButton(j), 'CData', obj.GUIData.OnButtonDark);
                            else
                                set(obj.GUIHandles.PortValveButton(j), 'CData', obj.GUIData.OffButtonDark);
                            end
                        end
                    end
                end
            case 'V' % Valve controlled by output line (not SPI shift register)
                if obj.GUIData.CurrentPanel == 1
                    if thisChannelState == 1
                        set(obj.GUIHandles.PortValveButton(i-obj.HW.Pos.Output_Valve+1), 'CData', obj.GUIData.OnButtonDark);
                    else
                        set(obj.GUIHandles.PortValveButton(i-obj.HW.Pos.Output_Valve+1), 'CData', obj.GUIData.OffButtonDark);
                    end
                end
            case 'B' % BNC (digital)
                if obj.GUIData.CurrentPanel == 1
                    if thisChannelState == 1
                        set(obj.GUIHandles.BNCOutputButton(i-obj.HW.Pos.Output_BNC+1), 'CData', obj.GUIData.OnButtonDark);
                    else
                        set(obj.GUIHandles.BNCOutputButton(i-obj.HW.Pos.Output_BNC+1), 'CData', obj.GUIData.OffButtonDark);
                    end
                end
            case 'W' % Wire (digital)
                if obj.GUIData.CurrentPanel == 1
                    if thisChannelState == 1
                        set(obj.GUIHandles.WireOutputButton(i-obj.HW.Pos.Output_Wire+1), 'CData', obj.GUIData.OnButtonDark);
                    else
                        set(obj.GUIHandles.WireOutputButton(i-obj.HW.Pos.Output_Wire+1), 'CData', obj.GUIData.OffButtonDark);
                    end
                end
            case 'P' % Port (PWM)
                if obj.GUIData.CurrentPanel == 1
                    if thisChannelState > 0
                        set(obj.GUIHandles.PortLEDButton(i-obj.HW.Pos.Output_PWM+1), 'CData', obj.GUIData.OnButtonDark);
                    else
                        set(obj.GUIHandles.PortLEDButton(i-obj.HW.Pos.Output_PWM+1), 'CData', obj.GUIData.OffButtonDark);
                    end
                end
        end
    end

    % Update input channel override button colors
    changedInputChannels = find(obj.HardwareState.InputState ~= obj.LastHardwareState.InputState);
    for i = changedInputChannels
        thisChannelType = obj.HardwareState.InputType(i);
        thisChannelState = obj.HardwareState.InputState(i);
        if obj.GUIData.CurrentPanel == 1
            switch thisChannelType
                case 'P' % Port (digital)
                    if thisChannelState == 1
                        set(obj.GUIHandles.PortvPokeButton(i-obj.HW.Pos.Input_Port+1), 'CData', obj.GUIData.OnButtonDark);
                    else
                        set(obj.GUIHandles.PortvPokeButton(i-obj.HW.Pos.Input_Port+1), 'CData', obj.GUIData.OffButtonDark);
                    end
                case 'B' % BNC (digital)
                    if thisChannelState == 1
                        set(obj.GUIHandles.BNCInputButton(i-obj.HW.Pos.Input_BNC+1), 'CData', obj.GUIData.OnButtonDark);
                    else
                        set(obj.GUIHandles.BNCInputButton(i-obj.HW.Pos.Input_BNC+1), 'CData', obj.GUIData.OffButtonDark);
                    end
                case 'W' % Wire (digital)
                    if thisChannelState == 1
                        set(obj.GUIHandles.WireInputButton(i-obj.HW.Pos.Input_Wire+1), 'CData', obj.GUIData.OnButtonDark);
                    else
                        set(obj.GUIHandles.WireInputButton(i-obj.HW.Pos.Input_Wire+1), 'CData', obj.GUIData.OffButtonDark);
                    end
            end
        end
    end
    obj.LastHardwareState = obj.HardwareState;
end