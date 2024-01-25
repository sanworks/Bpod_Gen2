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

% BpodObject.SetupStateMachine() uses the hardware description returned by
% SetupHardware() to construct the state machine assembler metadata in the StateMachineInfo field -
% events and channels, and indexes of channel and event types in those lists.
% It then compiles the blank state machine description returned to the user by NewStateMachine().
% SetupStateMachine() is called by SetupHardware() on startup, and by LoadModules()
% after polling for changes in connected Bpod modules.

function obj = SetupStateMachine(obj)

% Preallocate name vectors
eventNames = cell(1,sum(obj.Modules.nSerialEvents) + obj.HW.n.SoftCodes + obj.HW.n.DigitalInputs*2 + 16);
inputChannelNames = cell(1,obj.HW.n.Inputs);

% Initialize channel type counters
pos = 1;
nUSB = 0;
nUSB_APP = 0;
nBNCs = 0;
nWires = 0;
nPorts = 0;
nFlexIO = 0;
nChannels = 0;
nSoftCodesPerUSBChannel = obj.HW.n.SoftCodes/(obj.HW.n.USBChannels+obj.HW.n.USBChannels_External);

% Read input channel types from obj.HW.Inputs and setup event and channel names accordingly
for i = 1:obj.HW.n.Inputs
    switch obj.HW.Inputs(i)
        case 'U'
            nChannels = nChannels + 1;
            if obj.Modules.Connected(i)
                inputChannelNames{nChannels} = obj.Modules.Name{i};
            else
                inputChannelNames{nChannels} = ['Serial' num2str(i)];
            end
            for j = 1:obj.Modules.nSerialEvents(i)
                assigned = 0;
                if ~isempty(obj.Modules.EventNames{i})
                    if j <= length(obj.Modules.EventNames{i})
                        thisEventName = [inputChannelNames{nChannels} '_' obj.Modules.EventNames{i}{j}];
                        assigned = 1;
                    end
                end
                if ~assigned
                    thisEventName = [inputChannelNames{nChannels} '_' num2str(j)];
                end
                eventNames{pos} = thisEventName; pos = pos + 1;
            end
        case 'X'
            if nUSB == 0
                obj.HW.Pos.Event_USB = pos;
            end
            nChannels = nChannels + 1; nUSB = nUSB + 1;
            inputChannelNames{nChannels} = 'USB';
            for j = 1:nSoftCodesPerUSBChannel
                eventNames{pos} = ['SoftCode' num2str(j)]; pos = pos + 1;
            end
            if obj.MachineType < 3
                if pos < obj.HW.n.MaxSerialEvents
                    for j = obj.HW.n.SoftCodes+1:obj.HW.n.SoftCodes+(obj.HW.n.MaxSerialEvents-pos)+1
                        eventNames{pos} = ['SoftCode' num2str(j)]; pos = pos + 1;
                    end
                end
            end
        case 'Z'
            if nUSB_APP == 0
                obj.HW.Pos.Event_USB_APP = pos;
            end
            nChannels = nChannels + 1; nUSB_APP = nUSB_APP + 1;
            inputChannelNames{nChannels} = 'APP_USB';
            for j = 1:nSoftCodesPerUSBChannel
                eventNames{pos} = ['APP_SoftCode' num2str(j-1)]; pos = pos + 1;
            end
            if pos < obj.HW.n.MaxSerialEvents
                for j = obj.HW.n.SoftCodes+1:obj.HW.n.SoftCodes+(obj.HW.n.MaxSerialEvents-pos)+1
                    eventNames{pos} = ['APP_SoftCode' num2str(j-1)]; pos = pos + 1;
                end
            end
        case 'F'
            if nFlexIO == 0
                obj.HW.Pos.Event_FlexIO = pos;
            end
            nChannels = nChannels + 1; nFlexIO = nFlexIO + 1;
            if obj.HW.FlexIO_ChannelTypes(nFlexIO) == 0
                inputChannelNames{nChannels} = ['Flex' num2str(nFlexIO)];
                eventNames{pos} = [inputChannelNames{nChannels} 'High']; pos = pos + 1;
                eventNames{pos} = [inputChannelNames{nChannels} 'Low']; pos = pos + 1;
            elseif obj.HW.FlexIO_ChannelTypes(nFlexIO) == 2
                inputChannelNames{nChannels} = ['Flex' num2str(nFlexIO)];
                eventNames{pos} = [inputChannelNames{nChannels} 'Trig1']; pos = pos + 1;
                eventNames{pos} = [inputChannelNames{nChannels} 'Trig2']; pos = pos + 1;
            else
                inputChannelNames{nChannels} = '---';
                eventNames{pos} = '---'; pos = pos + 1;
                eventNames{pos} = '---'; pos = pos + 1;
            end
        case 'P'
            if nPorts == 0
                obj.HW.Pos.Event_Port = pos;
            end
            nPorts = nPorts + 1; nChannels = nChannels + 1;
            inputChannelNames{nChannels} = ['Port' num2str(nPorts)];
            eventNames{pos} = [inputChannelNames{nChannels} 'In']; pos = pos + 1;
            eventNames{pos} = [inputChannelNames{nChannels} 'Out']; pos = pos + 1;
        case 'B'
            if nBNCs == 0
                obj.HW.Pos.Event_BNC = pos;
            end
            nBNCs = nBNCs + 1; nChannels = nChannels + 1;
            inputChannelNames{nChannels} = ['BNC' num2str(nBNCs)];
            eventNames{pos} = [inputChannelNames{nChannels} 'High']; pos = pos + 1;
            eventNames{pos} = [inputChannelNames{nChannels} 'Low']; pos = pos + 1;
        case 'W'
            if nWires == 0
                obj.HW.Pos.Event_Wire = pos;
            end
            nWires = nWires + 1; nChannels = nChannels + 1;
            inputChannelNames{nChannels} = ['Wire' num2str(nWires)];
            eventNames{pos} = [inputChannelNames{nChannels} 'High']; pos = pos + 1;
            eventNames{pos} = [inputChannelNames{nChannels} 'Low']; pos = pos + 1;
    end
end

% Add global timer, counter and condition events
for i = 1:obj.HW.n.GlobalTimers
    eventNames{pos} = ['GlobalTimer' num2str(i) '_Start']; pos = pos + 1;
end
for i = 1:obj.HW.n.GlobalTimers
    eventNames{pos} = ['GlobalTimer' num2str(i) '_End']; pos = pos + 1;
end
for i = 1:obj.HW.n.GlobalCounters
    eventNames{pos} = ['GlobalCounter' num2str(i) '_End']; pos = pos + 1;
end
for i = 1:obj.HW.n.Conditions
    eventNames{pos} = ['Condition' num2str(i)]; pos = pos + 1;
end

% Add the state timer event
eventNames{pos} = 'Tup';

% Update StateMachineInfo
obj.StateMachineInfo.EventNames = eventNames;
obj.StateMachineInfo.InputChannelNames = inputChannelNames;

% Calculate positions of event types in the list of events
obj.HW.StateTimerPosition = pos;
obj.HW.IOEventStartposition = find(obj.HW.EventTypes == 'I', 1);
obj.HW.GlobalTimerStartposition = find(obj.HW.EventTypes == 'T', 1);
obj.HW.GlobalCounterStartposition = find(obj.HW.EventTypes == '+', 1);
obj.HW.ConditionStartposition = find(obj.HW.EventTypes == 'C', 1);
obj.HW.StateTimerPosition = find(obj.HW.EventTypes == 'U');

% Preallocate output channel name vector
outputChannelNames = cell(1,obj.HW.n.Outputs + 3);

% Initialize channel type counters
pos = 0;
nUSB = 0;
nUSB_APP = 0;
nFlexIO = 0;
nSPI = 0;
nBNCs = 0;
nWires = 0;
nPorts = 0;
nValves = 0;

% Read output channel types from obj.HW.Outputs and setup event and channel names accordingly
for i = 1:obj.HW.n.Outputs
    pos = pos + 1;
    switch obj.HW.Outputs(i)
        case 'U'
            if obj.Modules.Connected(i)
                outputChannelNames{pos} = obj.Modules.Name{i};
            else
                outputChannelNames{pos} = ['Serial' num2str(i)];
                obj.Modules.Name{i} = outputChannelNames{pos};
            end
        case 'X'
            outputChannelNames{pos} = 'SoftCode';
            if nUSB == 0
                obj.HW.Pos.Output_USB = pos;
                nUSB = 1;
            end
        case 'Z'
            outputChannelNames{pos} = 'APP_SoftCode';
            if nUSB_APP == 0
                obj.HW.Pos.Output_USB_APP = pos;
                nUSB_APP = 1;
            end
        case 'F' % FlexIO output
            if nFlexIO == 0
                obj.HW.Pos.Output_FlexIO = pos;
            end
            nFlexIO = nFlexIO + 1;
            if obj.HW.FlexIO_ChannelTypes(nFlexIO) == 1
                outputChannelNames{pos} = ['Flex' num2str(nFlexIO) 'DO'];
            elseif obj.HW.FlexIO_ChannelTypes(nFlexIO) == 3
                outputChannelNames{pos} = ['Flex' num2str(nFlexIO) 'AO'];
            else
                outputChannelNames{pos} = '---';
            end
        case 'S' % Valves controlled by an SPI shift register
            if nSPI == 0
                obj.HW.Pos.Output_SPI = pos;
                nSPI = nSPI + 1;
            end
            outputChannelNames{pos} = 'ValveState'; % Assumes SPI valve shift register
        case 'V' % Valves controlled by individual logic lines
            if nValves == 0
                obj.HW.Pos.Output_Valve = pos;
            end
            nValves = nValves + 1;
            outputChannelNames{pos} = ['Valve' num2str(nValves)];
        case 'P'
            if nPorts == 0
                obj.HW.Pos.Output_PWM = pos;
            end
            nPorts = nPorts + 1;
            outputChannelNames{pos} = ['PWM' num2str(nPorts)];
        case 'B'
            if nBNCs == 0
                obj.HW.Pos.Output_BNC = pos;
            end
            nBNCs = nBNCs + 1;
            outputChannelNames{pos} = ['BNC' num2str(nBNCs)];
        case 'W'
            if nWires == 0
                obj.HW.Pos.Output_Wire = pos;
            end
            nWires = nWires + 1;
            outputChannelNames{pos} = ['Wire' num2str(nWires)];
    end
end

% Add outputs to set & reset global timers and counters
pos = pos + 1;
outputChannelNames{pos} = 'GlobalTimerTrig';
obj.HW.Pos.GlobalTimerTrig = pos;
pos = pos + 1;
outputChannelNames{pos} = 'GlobalTimerCancel';
obj.HW.Pos.GlobalTimerCancel = pos;
pos = pos + 1;
outputChannelNames{pos} = 'GlobalCounterReset';
obj.HW.Pos.GlobalCounterReset = pos;

% Add outputs to enable/disable FlexIO analog thresholds
if obj.MachineType > 3
    pos = pos + 1;
    outputChannelNames{pos} = 'AnalogThreshEnable';
    obj.HW.Pos.AnalogThreshEnable = pos;
    pos = pos + 1;
    outputChannelNames{pos} = 'AnalogThreshDisable';
    obj.HW.Pos.AnalogThreshDisable = pos;
end

% Update StateMachineInfo
obj.StateMachineInfo.OutputChannelNames = outputChannelNames;
obj.StateMachineInfo.nEvents = length(obj.StateMachineInfo.EventNames);
obj.StateMachineInfo.nOutputChannels = length(obj.StateMachineInfo.OutputChannelNames);

% Create blank state matrix to store in BpodObject.BlankStateMachine
sma.meta = struct;
sma.nStates = 0; % Number of states added
sma.nStatesInManifest = 0; % Number of states added + referred to in 'StateChangeConditions' section of AddState()
sma.Manifest = cell(1,obj.StateMachineInfo.MaxStates); % State names in the order they were added by user
sma.StateNames = {'Placeholder'}; % State names in the order they were referenced
nExtraEvents = obj.HW.n.GlobalTimers*2 + obj.HW.n.GlobalCounters + obj.HW.n.Conditions;
sma.meta.InputMatrixSize = obj.StateMachineInfo.nEvents-(nExtraEvents+1); % Subtract Global timers/counters/conditions and tup
sma.InputMatrix = ones(1,sma.meta.InputMatrixSize); % Matrix indicating what state to enter if each event (columns) occurs during each state (rows)
sma.meta.OutputMatrixSize = obj.StateMachineInfo.nOutputChannels; % Size of output matrix
sma.meta.use255BackSignal = 0; % Byte (set to 0 or 1) indicating whether byte 255 is a code to go back to the previous state.
% This is 0 by default, and automatically set to 1 if reserved word '>back' is used as a state name.
sma.OutputMatrix = zeros(1,sma.meta.OutputMatrixSize); % Matrix indicating the value to push to each output channel (columns) on entering each state (rows)
sma.StateTimerMatrix = zeros(1,1); % Array indicating which state to enter if each state's timer elapses
sma.GlobalTimerStartMatrix = ones(1,obj.HW.n.GlobalTimers); % Matrix indicating which state to enter if each global timer (columns) starts in each state (rows)
sma.GlobalTimerEndMatrix = ones(1,obj.HW.n.GlobalTimers); % Matrix indicating which state to enter if each global timer (columns) ends in each state (rows)
sma.GlobalTimers = struct; % Struct with configuration of each global timer, set by the user in AddGlobalTimer()
sma.GlobalTimers.Duration = zeros(1,obj.HW.n.GlobalTimers); % Duration the timer will run for once triggered (after the onset delay)
sma.GlobalTimers.OnsetDelay = zeros(1,obj.HW.n.GlobalTimers); % A delay between when the timer is triggered and when it starts running
sma.GlobalTimers.OutputChannel = ones(1,obj.HW.n.GlobalTimers)*255; % Default channel code of 255 is "no channel".
sma.GlobalTimers.OnMessage = zeros(1,obj.HW.n.GlobalTimers); % A PWM value, logic level or byte to send on the output channel when timer turns on
sma.GlobalTimers.OffMessage = zeros(1,obj.HW.n.GlobalTimers); % A PWM value, logic level or byte to send on the output channel when timer turns off
sma.GlobalTimers.TimerOn_Trigger = zeros(1,obj.HW.n.GlobalTimers); % An integer whose bits indicate other global timers to trigger when timer turns on
sma.GlobalTimers.LoopInterval = zeros(1,obj.HW.n.GlobalTimers); % An optional interval between timer loop cycles
sma.GlobalTimers.LoopMode = zeros(1,obj.HW.n.GlobalTimers); % Set to 1 if timer loops until canceled or trial-end
sma.GlobalTimers.SendEvents = ones(1,obj.HW.n.GlobalTimers); % Set to 0 to disable global timer events (if looping at high freq)
sma.GlobalTimers.Names = cell(1,obj.HW.n.GlobalTimers); % Global timer names (used only for BControl)
sma.GlobalTimers.IsSet = zeros(1,obj.HW.n.GlobalTimers); % Changed to 1 when each timer is set with SetGlobalTimer()
sma.GlobalCounterMatrix = ones(1,obj.HW.n.GlobalCounters); % Matrix indicating which state to enter if each global counter (columns) exceeds threshold in each state (rows)
sma.GlobalCounterEvents = ones(1,obj.HW.n.GlobalCounters)*255; % Default event of 255 is code for "no event attached".
sma.GlobalCounterThresholds = zeros(1,obj.HW.n.GlobalCounters); % Thresholds of each global counter (number of events counted before generating a global counter event)
sma.GlobalCounterSet = zeros(1,obj.HW.n.GlobalCounters); % Changed to 1 when the counter event is identified and given a threshold with SetGlobalCounter
sma.ConditionMatrix = ones(1,obj.HW.n.Conditions); % Matrix indicating which state to enter if each condition (columns) is true on entering each state (rows)
sma.ConditionChannels = zeros(1,obj.HW.n.Conditions); % Channel evaluated by to each condition
sma.ConditionValues = zeros(1,obj.HW.n.Conditions); % Value of the channel for the condition to be true.
sma.ConditionNames = cell(1,obj.HW.n.Conditions); % Condition names (used only for BControl)
sma.ConditionSet = zeros(1,obj.HW.n.Conditions); % Changed to 1 when each condition is set with AddCondition()
sma.StateTimers = 0; % For each state, time until the state timer ends
sma.StatesDefined = 1; % Referenced states are set to 0. Defined states are set to 1. Both occur with AddState
sma.SerialMessageMode = 0; % 0 if manually programmed with LoadSerialMessages(), 1 if programmed implicitly
sma.nSerialMessages = zeros(1,obj.HW.n.UartSerialChannels);
sma.SerialMessages = cell(obj.HW.n.UartSerialChannels,256);

% Assign the blank state machine to BpodObject.BlankStateMachine
obj.BlankStateMachine = sma;
end