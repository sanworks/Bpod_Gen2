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
function obj = SetupStateMachine(obj)
    % Set up event and output names
    EventNames = cell(1,sum(obj.Modules.nSerialEvents) + obj.HW.n.SoftCodes + obj.HW.n.DigitalInputs*2 + 16);
    InputChannelNames = cell(1,obj.HW.n.Inputs);
    Pos = 1;
    nUSB = 0;
    nBNCs = 0;
    nWires = 0;
    nPorts = 0;
    nFlexIO = 0;
    nChannels = 0;
    for i = 1:obj.HW.n.Inputs
        switch obj.HW.Inputs(i)
            case 'U'
                nChannels = nChannels + 1;
                if obj.Modules.Connected(i)
                    InputChannelNames{nChannels} = obj.Modules.Name{i};
                else
                    InputChannelNames{nChannels} = ['Serial' num2str(i)];
                end
                for j = 1:obj.Modules.nSerialEvents(i)
                    Assigned = 0;
                    if ~isempty(obj.Modules.EventNames{i})
                        if j <= length(obj.Modules.EventNames{i})
                            ThisEventName = [InputChannelNames{nChannels} '_' obj.Modules.EventNames{i}{j}];
                            Assigned = 1;
                        end
                    end
                    if ~Assigned
                        ThisEventName = [InputChannelNames{nChannels} '_' num2str(j)];
                    end
                    EventNames{Pos} = ThisEventName; Pos = Pos + 1;
                end
            case 'X'
                if nUSB == 0
                    obj.HW.Pos.Event_USB = Pos;
                end
                nChannels = nChannels + 1; nUSB = nUSB + 1;
                InputChannelNames{nChannels} = 'USB';
                for j = 1:obj.HW.n.SoftCodes;
                    EventNames{Pos} = ['SoftCode' num2str(j)]; Pos = Pos + 1;
                end
                if Pos < obj.HW.n.MaxSerialEvents
                    for j = obj.HW.n.SoftCodes+1:obj.HW.n.SoftCodes+(obj.HW.n.MaxSerialEvents-Pos)+1
                        EventNames{Pos} = ['SoftCode' num2str(j)]; Pos = Pos + 1;
                    end
                end
            case 'F'
                if nFlexIO == 0
                    obj.HW.Pos.Event_FlexIO = Pos;
                end
                nChannels = nChannels + 1; nFlexIO = nFlexIO + 1;
                if obj.HW.FlexIOChannelTypes(nFlexIO) == 0
                    InputChannelNames{nChannels} = ['Flex' num2str(nFlexIO)];
                    EventNames{Pos} = [InputChannelNames{nChannels} 'High']; Pos = Pos + 1;
                    EventNames{Pos} = [InputChannelNames{nChannels} 'Low']; Pos = Pos + 1;
                elseif obj.HW.FlexIOChannelTypes(nFlexIO) == 2
                    InputChannelNames{nChannels} = ['Flex' num2str(nFlexIO)];
                    EventNames{Pos} = [InputChannelNames{nChannels} 'Trig']; Pos = Pos + 1;
                    EventNames{Pos} = [InputChannelNames{nChannels} 'Reset']; Pos = Pos + 1;
                else
                    InputChannelNames{nChannels} = '---';
                    EventNames{Pos} = '---'; Pos = Pos + 1;
                    EventNames{Pos} = '---'; Pos = Pos + 1;
                end
            case 'P'
                if nPorts == 0
                    obj.HW.Pos.Event_Port = Pos;
                end
                nPorts = nPorts + 1; nChannels = nChannels + 1;
                InputChannelNames{nChannels} = ['Port' num2str(nPorts)];
                EventNames{Pos} = [InputChannelNames{nChannels} 'In']; Pos = Pos + 1;
                EventNames{Pos} = [InputChannelNames{nChannels} 'Out']; Pos = Pos + 1;
            case 'B'
                if nBNCs == 0
                    obj.HW.Pos.Event_BNC = Pos;
                end
                nBNCs = nBNCs + 1; nChannels = nChannels + 1;
                InputChannelNames{nChannels} = ['BNC' num2str(nBNCs)];
                EventNames{Pos} = [InputChannelNames{nChannels} 'High']; Pos = Pos + 1;
                EventNames{Pos} = [InputChannelNames{nChannels} 'Low']; Pos = Pos + 1;
            case 'W'
                if nWires == 0
                    obj.HW.Pos.Event_Wire = Pos;
                end
                nWires = nWires + 1; nChannels = nChannels + 1;
                InputChannelNames{nChannels} = ['Wire' num2str(nWires)];
                EventNames{Pos} = [InputChannelNames{nChannels} 'High']; Pos = Pos + 1;
                EventNames{Pos} = [InputChannelNames{nChannels} 'Low']; Pos = Pos + 1;
        end
    end
    for i = 1:obj.HW.n.GlobalTimers
        EventNames{Pos} = ['GlobalTimer' num2str(i) '_Start']; Pos = Pos + 1;
    end
    for i = 1:obj.HW.n.GlobalTimers
        EventNames{Pos} = ['GlobalTimer' num2str(i) '_End']; Pos = Pos + 1;
    end
    for i = 1:obj.HW.n.GlobalCounters
        EventNames{Pos} = ['GlobalCounter' num2str(i) '_End']; Pos = Pos + 1;
    end
    for i = 1:obj.HW.n.Conditions
        EventNames{Pos} = ['Condition' num2str(i)]; Pos = Pos + 1;
    end
    EventNames{Pos} = 'Tup';
    obj.StateMachineInfo.EventNames = EventNames;
    obj.StateMachineInfo.InputChannelNames = InputChannelNames;
    obj.HW.StateTimerPosition = Pos;

    obj.HW.IOEventStartposition = find(obj.HW.EventTypes == 'I', 1);
    obj.HW.GlobalTimerStartposition = find(obj.HW.EventTypes == 'T', 1);
    obj.HW.GlobalCounterStartposition = find(obj.HW.EventTypes == '+', 1);
    obj.HW.ConditionStartposition = find(obj.HW.EventTypes == 'C', 1);
    obj.HW.StateTimerPosition = find(obj.HW.EventTypes == 'U');

    OutputChannelNames = cell(1,obj.HW.n.Outputs + 3);
    Pos = 0;
    nUSB = 0;
    nFlexIO = 0;
    nSPI = 0;
    nBNCs = 0;
    nWires = 0;
    nPorts = 0;
    nValves = 0;
    for i = 1:obj.HW.n.Outputs
        Pos = Pos + 1;
        switch obj.HW.Outputs(i)
            case 'U'
                if obj.Modules.Connected(i)
                    OutputChannelNames{Pos} = obj.Modules.Name{i};
                else
                    OutputChannelNames{Pos} = ['Serial' num2str(i)];
                    obj.Modules.Name{i} = OutputChannelNames{Pos};
                end
            case 'X'
                OutputChannelNames{Pos} = 'SoftCode';
                if nUSB == 0
                    obj.HW.Pos.Output_USB = Pos;
                    nUSB = 1;
                end
            case 'F' % FlexIO output
                if nFlexIO == 0
                    obj.HW.Pos.Output_FlexIO = Pos;
                end
                nFlexIO = nFlexIO + 1;
                if obj.HW.FlexIOChannelTypes(nFlexIO) == 1
                    OutputChannelNames{Pos} = ['Flex' num2str(nFlexIO) 'DO'];
                elseif obj.HW.FlexIOChannelTypes(nFlexIO) == 3
                    OutputChannelNames{Pos} = ['Flex' num2str(nFlexIO) 'AO'];
                else
                    OutputChannelNames{Pos} = '---';
                end
            case 'S' % Valves controlled by an SPI shift register
                if nSPI == 0
                    obj.HW.Pos.Output_SPI = Pos;
                    nSPI = nSPI + 1;
                end
                OutputChannelNames{Pos} = 'ValveState'; % Assumes SPI valve shift register
            case 'V' % Valves controlled by individual logic lines
                if nValves == 0
                    obj.HW.Pos.Output_Valve = Pos;
                end
                nValves = nValves + 1;
                OutputChannelNames{Pos} = ['Valve' num2str(nValves)];
            case 'P'
                if nPorts == 0
                    obj.HW.Pos.Output_PWM = Pos;
                end
                nPorts = nPorts + 1;
                OutputChannelNames{Pos} = ['PWM' num2str(nPorts)];
            case 'B'
                if nBNCs == 0
                    obj.HW.Pos.Output_BNC = Pos;
                end
                nBNCs = nBNCs + 1;
                OutputChannelNames{Pos} = ['BNC' num2str(nBNCs)];
            case 'W'
                if nWires == 0
                    obj.HW.Pos.Output_Wire = Pos;
                end
                nWires = nWires + 1;
                OutputChannelNames{Pos} = ['Wire' num2str(nWires)];
        end
    end
    Pos = Pos + 1;
    OutputChannelNames{Pos} = 'GlobalTimerTrig';
    obj.HW.Pos.GlobalTimerTrig = Pos;
    Pos = Pos + 1;
    OutputChannelNames{Pos} = 'GlobalTimerCancel';
    obj.HW.Pos.GlobalTimerCancel = Pos;
    Pos = Pos + 1;
    OutputChannelNames{Pos} = 'GlobalCounterReset';
    obj.HW.Pos.GlobalCounterReset = Pos;
    obj.StateMachineInfo.OutputChannelNames = OutputChannelNames;
    obj.StateMachineInfo.nEvents = length(obj.StateMachineInfo.EventNames);
    obj.StateMachineInfo.nOutputChannels = length(obj.StateMachineInfo.OutputChannelNames);
    % Create blank state matrix to store in Bpod object
    sma.meta = struct;
    sma.nStates = 0;
    sma.nStatesInManifest = 0;
    sma.Manifest = cell(1,obj.StateMachineInfo.MaxStates); % State names in the order they were added by user
    sma.StateNames = {'Placeholder'}; % State names in the order they were referenced
    nExtraEvents = obj.HW.n.GlobalTimers*2 + obj.HW.n.GlobalCounters + obj.HW.n.Conditions;
    sma.meta.InputMatrixSize = obj.StateMachineInfo.nEvents-(nExtraEvents+1); % Subtract Global timers/counters/conditions and tup
    sma.InputMatrix = ones(1,sma.meta.InputMatrixSize);
    sma.meta.OutputMatrixSize = obj.StateMachineInfo.nOutputChannels;
    sma.meta.use255BackSignal = 0; % Byte (set to 0 or 1) indicating whether byte 255 is a code to go back to the previous state.
                                   % This is 0 by default, and automatically set to 1 if reserved word '>back' is used as a state name.
    sma.OutputMatrix = zeros(1,sma.meta.OutputMatrixSize);
    sma.StateTimerMatrix = zeros(1,1);
    sma.GlobalTimerStartMatrix = ones(1,obj.HW.n.GlobalTimers);
    sma.GlobalTimerEndMatrix = ones(1,obj.HW.n.GlobalTimers);
    sma.GlobalTimers = struct;
    sma.GlobalTimers.Duration = zeros(1,obj.HW.n.GlobalTimers);
    sma.GlobalTimers.OnsetDelay = zeros(1,obj.HW.n.GlobalTimers); % A delay between when the timer is triggered and when it turns on
    sma.GlobalTimers.OutputChannel = ones(1,obj.HW.n.GlobalTimers)*255; % Default channel code of 255 is "no channel".
    sma.GlobalTimers.OnMessage = zeros(1,obj.HW.n.GlobalTimers); % A PWM value, logic level or byte to send on the output channel when timer turns on
    sma.GlobalTimers.OffMessage = zeros(1,obj.HW.n.GlobalTimers); % A PWM value, logic level or byte to send on the output channel when timer turns off
    sma.GlobalTimers.TimerOn_Trigger = zeros(1,obj.HW.n.GlobalTimers); % An integer whose bits indicate other global timers to trigger when timer turns on
    sma.GlobalTimers.LoopInterval = zeros(1,obj.HW.n.GlobalTimers); % An optional interval between timer loop cycles
    sma.GlobalTimers.LoopMode = zeros(1,obj.HW.n.GlobalTimers); % Set to 1 if timer loops until canceled or trial-end
    sma.GlobalTimers.SendEvents = ones(1,obj.HW.n.GlobalTimers); % Set to 0 to disable global timer events (if looping at high freq)
    sma.GlobalTimers.Names = cell(1,obj.HW.n.GlobalTimers);
    sma.GlobalTimers.IsSet = zeros(1,obj.HW.n.GlobalTimers); % Changed to 1 when the timer is set with SetGlobalTimer
    sma.GlobalCounterMatrix = ones(1,obj.HW.n.GlobalCounters);
    sma.GlobalCounterEvents = ones(1,obj.HW.n.GlobalCounters)*255; % Default event of 255 is code for "no event attached".
    sma.GlobalCounterThresholds = zeros(1,obj.HW.n.GlobalCounters);
    sma.GlobalCounterSet = zeros(1,obj.HW.n.GlobalCounters); % Changed to 1 when the counter event is identified and given a threshold with SetGlobalCounter
    sma.ConditionMatrix = ones(1,obj.HW.n.Conditions);
    sma.ConditionChannels = zeros(1,obj.HW.n.Conditions);
    sma.ConditionValues = zeros(1,obj.HW.n.Conditions);
    sma.ConditionNames = cell(1,obj.HW.n.Conditions);
    sma.ConditionSet = zeros(1,obj.HW.n.Conditions);
    sma.StateTimers = 0;
    sma.StatesDefined = 1; % Referenced states are set to 0. Defined states are set to 1. Both occur with AddState
    sma.SerialMessageMode = 0; % 0 if manually programmed with LoadSerialMessages(), 1 if programmed implicitly
    sma.nSerialMessages = zeros(1,obj.HW.n.UartSerialChannels);
    sma.SerialMessages = cell(obj.HW.n.UartSerialChannels,256);
    obj.BlankStateMachine = sma;
end